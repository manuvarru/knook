import AppKit
@preconcurrency import Combine
import Foundation

enum UpdateState: Equatable {
    case idle
    case available(version: String, releaseURL: URL?)
    case installing
    case installingProgress(step: String)
    case installed
    case error(String)

    var isAvailable: Bool {
        if case .available = self {
            return true
        }
        return false
    }

    var versionString: String? {
        if case let .available(version, _) = self {
            return version
        }
        return nil
    }

    var releasePageURL: URL? {
        if case let .available(_, releaseURL) = self {
            return releaseURL
        }
        return nil
    }

    var errorMessage: String? {
        if case let .error(message) = self {
            return message
        }
        return nil
    }
}

@MainActor
protocol UpdateManaging: AnyObject {
    var statePublisher: AnyPublisher<UpdateState, Never> { get }
    func checkForUpdates()
    func installAvailableUpdate()
    func installViaTerminalFallback()
}

@MainActor
final class NullUpdateManager: UpdateManaging {
    private let stateSubject = CurrentValueSubject<UpdateState, Never>(.idle)

    var statePublisher: AnyPublisher<UpdateState, Never> {
        stateSubject.eraseToAnyPublisher()
    }

    func checkForUpdates() {
        stateSubject.send(.error("La ricerca aggiornamenti non è disponibile per questa build."))
    }

    func installAvailableUpdate() {
        stateSubject.send(.error("La ricerca aggiornamenti non è disponibile per questa build."))
    }

    func installViaTerminalFallback() {
        stateSubject.send(.error("La ricerca aggiornamenti non è disponibile per questa build."))
    }
}

struct GitHubRelease: Equatable {
    let version: String
    let releaseURL: URL
    let isDraft: Bool
    let isPrerelease: Bool
}

protocol GitHubReleaseFetching: Sendable {
    func fetchLatestRelease() async throws -> GitHubRelease
}

protocol BrewPathProviding: Sendable {
    func brewPath() -> String?
}

protocol ExternalUpdateHandling: Sendable {
    func openTerminal(with command: String) throws
    func openURL(_ url: URL)
    func quitAndRelaunch() throws
}

struct URLSessionGitHubReleaseFetcher: GitHubReleaseFetching {
    private let session: URLSession
    private let apiURL: URL

    init(
        session: URLSession = .shared,
        apiURL: URL = AppUpdateSource.latestReleaseAPIURL
    ) {
        self.session = session
        self.apiURL = apiURL
    }

    func fetchLatestRelease() async throws -> GitHubRelease {
        var request = URLRequest(url: apiURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("knook", forHTTPHeaderField: "User-Agent")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubReleaseError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw GitHubReleaseError.unexpectedStatusCode(httpResponse.statusCode)
        }

        let decoded = try JSONDecoder().decode(GitHubLatestReleaseResponse.self, from: data)

        guard !decoded.tagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw GitHubReleaseError.missingTag
        }

        return GitHubRelease(
            version: decoded.tagName,
            releaseURL: decoded.htmlURL,
            isDraft: decoded.draft,
            isPrerelease: decoded.prerelease
        )
    }
}

struct DefaultBrewPathProvider: BrewPathProviding {
    func brewPath() -> String? {
        let candidates = [
            "/opt/homebrew/bin/brew",
            "/usr/local/bin/brew",
        ]

        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }
}

struct SystemExternalUpdateHandler: ExternalUpdateHandling {
    func openTerminal(with command: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = [
            "-e", "tell application \"Terminal\" to activate",
            "-e", "tell application \"Terminal\" to do script \(Self.appleScriptStringLiteral(command))",
        ]
        try process.run()
    }

    func openURL(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    func quitAndRelaunch() throws {
        let bundleURL = Bundle.main.bundleURL
        // Prefer the .app bundle path. If running from a non-.app context
        // (e.g. swift run), fall back to the Homebrew cask install location.
        let appPath: String
        if bundleURL.pathExtension == "app" {
            appPath = bundleURL.path
        } else {
            appPath = "/Applications/Knook Ita.app"
        }

        let pid = ProcessInfo.processInfo.processIdentifier

        let script = """
        while kill -0 \(pid) 2>/dev/null; do sleep 0.2; done
        open "\(appPath)"
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", script]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()

        DispatchQueue.main.async {
            NSApplication.shared.terminate(nil)
        }
    }

    private static func appleScriptStringLiteral(_ string: String) -> String {
        "\"\(string.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))\""
    }
}

@MainActor
final class GitHubReleaseUpdateManager: UpdateManaging {
    private static let lastUpdateCheckDateKey = "io.github.manuvarru.knook.lastUpdateCheckDate"

    private let stateSubject = CurrentValueSubject<UpdateState, Never>(.idle)
    private let releaseFetcher: any GitHubReleaseFetching
    private let brewPathProvider: any BrewPathProviding
    private let externalHandler: any ExternalUpdateHandling
    private let brewUpdateRunner: any BrewUpdateRunning
    private let currentVersion: String
    private let releasePageFallbackURL: URL
    private let automaticCheckInterval: TimeInterval
    private let userDefaults: UserDefaults
    private let nowProvider: () -> Date

    private var automaticCheckTimer: Timer?
    private var checkTask: Task<Void, Never>?
    private var installTask: Task<Void, Never>?
    private var availableRelease: GitHubRelease?

    var currentState: UpdateState {
        stateSubject.value
    }

    var statePublisher: AnyPublisher<UpdateState, Never> {
        stateSubject.eraseToAnyPublisher()
    }

    init(
        releaseFetcher: any GitHubReleaseFetching = URLSessionGitHubReleaseFetcher(),
        brewPathProvider: any BrewPathProviding = DefaultBrewPathProvider(),
        externalHandler: any ExternalUpdateHandling = SystemExternalUpdateHandler(),
        brewUpdateRunner: any BrewUpdateRunning = BrewUpdateRunner(),
        currentVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0",
        releasePageFallbackURL: URL = AppUpdateSource.latestReleasePageURL,
        automaticCheckInterval: TimeInterval = 86_400,
        userDefaults: UserDefaults = .standard,
        nowProvider: @escaping () -> Date = Date.init,
        startsAutomaticChecks: Bool = true
    ) {
        self.releaseFetcher = releaseFetcher
        self.brewPathProvider = brewPathProvider
        self.externalHandler = externalHandler
        self.brewUpdateRunner = brewUpdateRunner
        self.currentVersion = currentVersion
        self.releasePageFallbackURL = releasePageFallbackURL
        self.automaticCheckInterval = automaticCheckInterval
        self.userDefaults = userDefaults
        self.nowProvider = nowProvider

        if startsAutomaticChecks {
            performAutomaticCheckIfDue()
            scheduleAutomaticChecks()
        }
    }

    func checkForUpdates() {
        startUpdateCheck(trigger: .manual)
    }

    func checkForUpdatesForTesting() async {
        await performUpdateCheck(trigger: .manual)
    }

    func installAvailableUpdate() {
        guard let availableRelease else {
            stateSubject.send(.error("Al momento non è disponibile alcun aggiornamento."))
            return
        }

        guard let brewPath = brewPathProvider.brewPath() else {
            externalHandler.openURL(availableRelease.releaseURL)
            publishAvailableRelease(availableRelease)
            return
        }

        stateSubject.send(.installing)

        let runner = brewUpdateRunner
        let stateSubject = stateSubject
        let externalHandler = externalHandler
        let targetVersion = GitHubReleaseUpdateManager.normalizedVersion(availableRelease.version)

        installTask = Task { @MainActor in
            let result = await runner.runUpdate(brewPath: brewPath, expectedVersion: targetVersion) { step in
                stateSubject.send(.installingProgress(step: step))
            }

            switch result {
            case .success:
                stateSubject.send(.installed)
                do {
                    try externalHandler.quitAndRelaunch()
                } catch {
                    stateSubject.send(.error("Aggiornamento installato, ma non è stato possibile riavviare. Riavvia Knook Ita manualmente."))
                }
            case let .failure(step, log):
                stateSubject.send(.error("Aggiornamento non riuscito durante: \(step)\n\(log.suffix(500))"))
            }
        }
    }

    func installViaTerminalFallback() {
        guard let brewPath = brewPathProvider.brewPath() else { return }
        do {
            try externalHandler.openTerminal(with: Self.homebrewUpdateCommand(using: brewPath))
        } catch {
            stateSubject.send(.error("Non è stato possibile aprire il Terminale. \(error.localizedDescription)"))
        }
    }

    private func performAutomaticCheckIfDue() {
        guard automaticCheckInterval > 0 else { return }

        let lastCheckDate = userDefaults.object(forKey: Self.lastUpdateCheckDateKey) as? Date
        guard lastCheckDate == nil || nowProvider().timeIntervalSince(lastCheckDate!) >= automaticCheckInterval else {
            return
        }

        startUpdateCheck(trigger: .automatic)
    }

    private func scheduleAutomaticChecks() {
        guard automaticCheckInterval > 0 else { return }

        let pollingInterval = min(automaticCheckInterval, 3_600)
        automaticCheckTimer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.performAutomaticCheckIfDue()
            }
        }
    }

    private func startUpdateCheck(trigger: UpdateCheckTrigger) {
        userDefaults.set(nowProvider(), forKey: Self.lastUpdateCheckDateKey)
        checkTask?.cancel()
        checkTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.performUpdateCheck(trigger: trigger)
        }
    }

    private func performUpdateCheck(trigger: UpdateCheckTrigger) async {
        do {
            let release = try await releaseFetcher.fetchLatestRelease()
            handleFetchedRelease(release)
        } catch is CancellationError {
            return
        } catch {
            handleFailedReleaseFetch(error, trigger: trigger)
        }
    }

    private func handleFetchedRelease(_ release: GitHubRelease) {
        guard !release.isDraft, !release.isPrerelease else {
            availableRelease = nil
            stateSubject.send(.idle)
            return
        }

        let normalizedRemoteVersion = Self.normalizedVersion(release.version)
        if Self.isVersion(normalizedRemoteVersion, newerThan: currentVersion) {
            let normalizedRelease = GitHubRelease(
                version: normalizedRemoteVersion,
                releaseURL: release.releaseURL,
                isDraft: release.isDraft,
                isPrerelease: release.isPrerelease
            )
            availableRelease = normalizedRelease
            publishAvailableRelease(normalizedRelease)
        } else {
            availableRelease = nil
            stateSubject.send(.idle)
        }
    }

    private func handleFailedReleaseFetch(_ error: any Error, trigger: UpdateCheckTrigger) {
        availableRelease = nil
        let prefix = trigger == .manual ? "Non è stato possibile cercare aggiornamenti." : "Ricerca automatica aggiornamenti non riuscita."
        stateSubject.send(.error("\(prefix) \(error.localizedDescription)"))
    }

    private func publishAvailableRelease(_ release: GitHubRelease) {
        stateSubject.send(.available(version: release.version, releaseURL: release.releaseURL))
    }

    static func normalizedVersion(_ version: String) -> String {
        version.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"^[vV]"#, with: "", options: .regularExpression)
    }

    static func isVersion(_ lhs: String, newerThan rhs: String) -> Bool {
        let left = versionComponents(from: lhs)
        let right = versionComponents(from: rhs)
        let maxCount = max(left.count, right.count)

        for index in 0..<maxCount {
            let leftComponent = index < left.count ? left[index] : 0
            let rightComponent = index < right.count ? right[index] : 0

            if leftComponent != rightComponent {
                return leftComponent > rightComponent
            }
        }

        return false
    }

    static func homebrewUpdateCommand(using brewPath: String) -> String {
        let quotedBrewPath = shellQuoted(brewPath)
        let quotedTap = shellQuoted(AppUpdateSource.homebrewTap)
        return "\(quotedBrewPath) untap \(quotedTap) 2>/dev/null; \(quotedBrewPath) tap \(quotedTap) && \(quotedBrewPath) update && (\(quotedBrewPath) upgrade --cask \(AppUpdateSource.homebrewCask) || \(quotedBrewPath) install --cask \(AppUpdateSource.homebrewCask))"
    }

    static func homebrewUpdateSteps(using brewPath: String) -> [(label: String, arguments: [String])] {
        [
            ("Aggiornamento tap...", ["untap", AppUpdateSource.homebrewTap]),
            ("Aggiornamento tap...", ["tap", AppUpdateSource.homebrewTap]),
            ("Aggiornamento Homebrew...", ["update"]),
            ("Installazione Knook Ita...", ["upgrade", "--cask", AppUpdateSource.homebrewCask]),
        ]
    }

    private static func versionComponents(from version: String) -> [Int] {
        normalizedVersion(version)
            .split(separator: ".")
            .map { component in
                let digits = component.prefix { $0.isNumber }
                return Int(digits) ?? 0
            }
    }

    private static func shellQuoted(_ string: String) -> String {
        "'\(string.replacingOccurrences(of: "'", with: "'\"'\"'"))'"
    }
}

enum AppUpdateSource {
    static let owner = "manuvarru"
    static let repository = "knook"
    static let homebrewTap = "manuvarru/tap"
    static let homebrewCask = "knook"

    static let latestReleaseAPIURL = URL(string: "https://api.github.com/repos/\(owner)/\(repository)/releases/latest")!
    static let latestReleasePageURL = URL(string: "https://github.com/\(owner)/\(repository)/releases/latest")!
}

private enum UpdateCheckTrigger {
    case automatic
    case manual
}

private enum GitHubReleaseError: LocalizedError {
    case invalidResponse
    case unexpectedStatusCode(Int)
    case missingTag

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "GitHub ha restituito una risposta non valida."
        case let .unexpectedStatusCode(statusCode):
            return "GitHub ha restituito HTTP \(statusCode)."
        case .missingTag:
            return "Nell'ultima release GitHub manca il tag di versione."
        }
    }
}

private struct GitHubLatestReleaseResponse: Decodable {
    let tagName: String
    let htmlURL: URL
    let draft: Bool
    let prerelease: Bool

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case draft
        case prerelease
    }
}
