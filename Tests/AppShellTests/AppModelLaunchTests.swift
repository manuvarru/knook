import Foundation
import Core
@testable import AppShell
import XCTest

@MainActor
final class AppModelLaunchTests: XCTestCase {
    private final class MockWorkspaceContextProvider: WorkspaceContextProviding {
        var currentSnapshot: WorkspaceContextSnapshot

        init(currentSnapshot: WorkspaceContextSnapshot) {
            self.currentSnapshot = currentSnapshot
        }

        func snapshot() -> WorkspaceContextSnapshot {
            currentSnapshot
        }
    }

    func testCompletedOnboardingLaunchesReadyWithoutOverride() throws {
        let store = try makeStore(with: completedSettings())

        let model = AppModel(
            settingsStore: store,
            launchConfiguration: AppLaunchConfiguration(forceOnboarding: false),
            startsTimer: false,
            observesSystemEvents: false
        )

        XCTAssertEqual(model.launchPhase, .ready)
        XCTAssertEqual(model.menuBarMode, .active)
    }

    func testCompletedOnboardingLaunchesSetupWithOverride() throws {
        let store = try makeStore(with: completedSettings())

        let model = AppModel(
            settingsStore: store,
            launchConfiguration: AppLaunchConfiguration(forceOnboarding: true),
            startsTimer: false,
            observesSystemEvents: false
        )

        XCTAssertEqual(model.launchPhase, .onboarding)
        XCTAssertEqual(model.menuBarMode, .setup)
    }

    func testIncompleteOnboardingLaunchesSetupWithoutOverride() throws {
        let store = try makeStore(with: .default)

        let model = AppModel(
            settingsStore: store,
            launchConfiguration: AppLaunchConfiguration(forceOnboarding: false),
            startsTimer: false,
            observesSystemEvents: false
        )

        XCTAssertEqual(model.launchPhase, .onboarding)
        XCTAssertEqual(model.menuBarMode, .setup)
    }

    func testForcedOnboardingDoesNotPersistResetUntilUserActs() throws {
        let originalSettings = completedSettings()
        let store = try makeStore(with: originalSettings)

        _ = AppModel(
            settingsStore: store,
            launchConfiguration: AppLaunchConfiguration(forceOnboarding: true),
            startsTimer: false,
            observesSystemEvents: false
        )

        let reloadedSettings = try store.load()

        XCTAssertEqual(reloadedSettings.onboardingState, originalSettings.onboardingState)
    }

    func testFinishOnboardingFlowPersistsPresetAndTransitionsAppToReady() throws {
        let store = try makeStore(with: .default)
        let model = AppModel(
            settingsStore: store,
            launchConfiguration: AppLaunchConfiguration(forceOnboarding: false),
            startsTimer: false,
            observesSystemEvents: false
        )

        model.finishOnboardingFlow(preset: .deepWork)

        XCTAssertEqual(model.launchPhase, .ready)
        XCTAssertEqual(model.menuBarMode, .active)
        XCTAssertTrue(model.onboardingState.hasCompletedStarterSetup)

        let reloadedSettings = try store.load()
        XCTAssertEqual(reloadedSettings.breakSettings.workInterval, 50 * 60)
        XCTAssertEqual(reloadedSettings.breakSettings.microBreakDuration, 10 * 60)
        XCTAssertFalse(reloadedSettings.breakSettings.longBreaksEnabled)
    }

    func testDismissStarterSetupWithDefaultsUsesEyeCarePreset() throws {
        let store = try makeStore(with: .default)
        let model = AppModel(
            settingsStore: store,
            launchConfiguration: AppLaunchConfiguration(forceOnboarding: false),
            startsTimer: false,
            observesSystemEvents: false
        )

        model.dismissStarterSetupWithDefaults()

        XCTAssertEqual(model.launchPhase, .ready)
        XCTAssertEqual(model.menuBarMode, .active)

        let reloadedSettings = try store.load()
        XCTAssertEqual(reloadedSettings.breakSettings.workInterval, 20 * 60)
        XCTAssertEqual(reloadedSettings.breakSettings.microBreakDuration, 20)
        XCTAssertTrue(reloadedSettings.breakSettings.longBreaksEnabled)
    }

    func testHandleAppDidFinishLaunchingPreservesOnboardingStateForFirstRun() throws {
        let store = try makeStore(with: .default)
        let model = AppModel(
            settingsStore: store,
            launchConfiguration: AppLaunchConfiguration(forceOnboarding: false),
            startsTimer: false,
            observesSystemEvents: false
        )

        model.handleAppDidFinishLaunching(now: Date(timeIntervalSinceReferenceDate: 500))

        XCTAssertEqual(model.launchPhase, .onboarding)
        XCTAssertEqual(model.menuBarMode, .setup)
        XCTAssertEqual(model.appState.statusText, "Completa la configurazione per iniziare il tuo ritmo di pause")
    }

    func testHandleAppDidFinishLaunchingPausesForFullscreenFocusWhenEnabled() throws {
        let store = try makeStore(with: completedSettings())
        let workspaceContextProvider = MockWorkspaceContextProvider(
            currentSnapshot: WorkspaceContextSnapshot(
                frontmostApplicationBundleIdentifier: "com.apple.Keynote",
                isFrontmostApplicationFullscreenFocused: true
            )
        )
        let model = AppModel(
            settingsStore: store,
            workspaceContextProvider: workspaceContextProvider,
            launchConfiguration: AppLaunchConfiguration(forceOnboarding: false),
            startsTimer: false,
            observesSystemEvents: false
        )

        model.handleAppDidFinishLaunching(now: Date(timeIntervalSinceReferenceDate: 500))

        XCTAssertTrue(model.appState.isPaused)
        XCTAssertEqual(model.appState.pauseReason, "app a schermo intero")
    }

    func testSaveSettingsUpdatesSmartPauseProviders() throws {
        var settings = completedSettings()
        settings.smartPauseSettings.pauseDuringFullscreenFocus = false
        let store = try makeStore(with: settings)
        let workspaceContextProvider = MockWorkspaceContextProvider(
            currentSnapshot: WorkspaceContextSnapshot(
                frontmostApplicationBundleIdentifier: "com.apple.Keynote",
                isFrontmostApplicationFullscreenFocused: true
            )
        )
        let model = AppModel(
            settingsStore: store,
            workspaceContextProvider: workspaceContextProvider,
            launchConfiguration: AppLaunchConfiguration(forceOnboarding: false),
            startsTimer: false,
            observesSystemEvents: false
        )

        model.handleAppDidFinishLaunching(now: Date(timeIntervalSinceReferenceDate: 500))
        XCTAssertFalse(model.appState.isPaused)

        model.settings.smartPauseSettings.pauseDuringFullscreenFocus = true
        model.saveSettings()
        model.tick(now: Date(timeIntervalSinceReferenceDate: 560))

        XCTAssertTrue(model.appState.isPaused)
        XCTAssertEqual(model.appState.pauseReason, "app a schermo intero")
    }

    private func completedSettings() -> AppSettings {
        var settings = AppSettings.default
        settings.onboardingState = OnboardingState(
            hasCompletedStarterSetup: true,
            completedAt: Date(timeIntervalSinceReferenceDate: 1234),
            lastCompletedVersion: AppSettings.currentSchemaVersion
        )
        return settings
    }

    private func makeStore(with settings: AppSettings) throws -> SettingsStore {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }

        let store = SettingsStore(fileURL: directory.appendingPathComponent("settings.json"))
        try store.save(settings)
        return store
    }
}
