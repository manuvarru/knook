import Foundation

enum BrewUpdateResult: Sendable {
    case success(log: String)
    case failure(step: String, log: String)
}

protocol BrewUpdateRunning: Sendable {
    func runUpdate(
        brewPath: String,
        expectedVersion: String,
        onProgress: @Sendable @MainActor (String) -> Void
    ) async -> BrewUpdateResult
}

struct BrewUpdateRunner: BrewUpdateRunning {
    func runUpdate(
        brewPath: String,
        expectedVersion: String,
        onProgress: @Sendable @MainActor (String) -> Void
    ) async -> BrewUpdateResult {
        var fullLog = ""

        let steps: [(label: String, args: [String], allowFailure: Bool)] = [
            ("Aggiornamento tap...", ["untap", AppUpdateSource.homebrewTap], true),
            ("Aggiornamento tap...", ["tap", AppUpdateSource.homebrewTap], false),
            ("Aggiornamento Homebrew...", ["update"], false),
        ]

        for step in steps {
            await onProgress(step.label)
            let result = runProcess(executablePath: brewPath, arguments: step.args)
            fullLog += "=== \(step.label) [\(step.args.joined(separator: " "))] ===\n\(result.output)\n"

            if result.exitCode != 0 && !step.allowFailure {
                return .failure(step: step.label, log: fullLog)
            }
        }

        // Install step: try upgrade first, fall back to install
        await onProgress("Installazione Knook Ita...")
        let upgradeResult = runProcess(executablePath: brewPath, arguments: ["upgrade", "--cask", AppUpdateSource.homebrewCask])
        fullLog += "=== Installazione Knook Ita... [upgrade --cask \(AppUpdateSource.homebrewCask)] ===\n\(upgradeResult.output)\n"

        if upgradeResult.exitCode != 0 {
            let installResult = runProcess(executablePath: brewPath, arguments: ["install", "--cask", AppUpdateSource.homebrewCask])
            fullLog += "=== Installazione Knook Ita... [install --cask \(AppUpdateSource.homebrewCask)] ===\n\(installResult.output)\n"

            if installResult.exitCode != 0 {
                return .failure(step: "Installazione Knook Ita...", log: fullLog)
            }
        }

        // Verify the installed version matches what we expected
        await onProgress("Verifica aggiornamento...")
        let infoResult = runProcess(executablePath: brewPath, arguments: ["list", "--cask", "--versions", AppUpdateSource.homebrewCask])
        fullLog += "=== Verifica aggiornamento... [list --cask --versions \(AppUpdateSource.homebrewCask)] ===\n\(infoResult.output)\n"

        let installedVersion = infoResult.output
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespaces)
            .last ?? ""

        if installedVersion != expectedVersion {
            return .failure(
                step: "Verifica aggiornamento...",
                log: fullLog + "\nVersione attesa \(expectedVersion), trovata \(installedVersion)."
            )
        }

        return .success(log: fullLog)
    }

    private func runProcess(executablePath: String, arguments: [String]) -> (exitCode: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        process.environment = buildEnvironment()

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return (-1, "Impossibile avviare il processo: \(error.localizedDescription)")
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        return (process.terminationStatus, output)
    }

    private func buildEnvironment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        env["NONINTERACTIVE"] = "1"
        env["HOMEBREW_NO_AUTO_UPDATE"] = "1"
        env["HOMEBREW_NO_INSTALL_CLEANUP"] = "1"
        return env
    }
}
