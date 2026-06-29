import Foundation
import Core
@testable import AppShell
import XCTest

@MainActor
final class AppModelTimerTests: XCTestCase {
    private final class MockActivityMonitor: ActivityMonitoring, @unchecked Sendable {
        var idleSeconds: TimeInterval

        init(idleSeconds: TimeInterval) {
            self.idleSeconds = idleSeconds
        }
    }

    private final class MockWindowCoordinator: WindowCoordinator {
        var onboardingVisible = false
        var showBreakOverlayCalls = 0
        var hideBreakOverlayCalls = 0
        var isBreakOverlayVisible = false
        var currentBreakOverlaySessionID: UUID?
        var shownBreakOverlaySessions: [BreakSession] = []

        func show(_ route: WindowRoute) {
            switch route {
            case .onboardingFlow:
                onboardingVisible = true
            case .breakOverlay:
                isBreakOverlayVisible = true
            default:
                break
            }
        }

        func hide(_ route: WindowRoute) {
            switch route {
            case .onboardingFlow:
                onboardingVisible = false
            case .breakOverlay:
                isBreakOverlayVisible = false
                currentBreakOverlaySessionID = nil
            default:
                break
            }
        }

        func hideAllTransientWindows() {
            isBreakOverlayVisible = false
            currentBreakOverlaySessionID = nil
        }

        func isVisible(_ route: WindowRoute) -> Bool {
            switch route {
            case .onboardingFlow:
                onboardingVisible
            case .breakOverlay:
                isBreakOverlayVisible
            default:
                false
            }
        }

        func showBreakOverlay(session: BreakSession) {
            showBreakOverlayCalls += 1
            isBreakOverlayVisible = true
            currentBreakOverlaySessionID = session.id
            shownBreakOverlaySessions.append(session)
        }

        func hideBreakOverlay() {
            hideBreakOverlayCalls += 1
            isBreakOverlayVisible = false
            currentBreakOverlaySessionID = nil
        }
    }

    func testWorkPhaseCountdownDecreasesEveryTick() throws {
        let coordinator = MockWindowCoordinator()
        let model = try makeModel(
            workInterval: 120,
            breakDuration: 20,
            windowCoordinator: coordinator
        )
        let start = Date(timeIntervalSinceReferenceDate: 1_000)

        model.handleAppDidFinishLaunching(now: start)
        XCTAssertEqual(model.appState.timerPhase, .work)
        XCTAssertEqual(model.appState.countdownText, "02:00")

        model.tick(now: start.addingTimeInterval(1))
        XCTAssertEqual(model.appState.countdownText, "01:59")
    }

    func testHighInitialIdleReadingDoesNotFreezeTimerAtLaunch() throws {
        let coordinator = MockWindowCoordinator()
        let activityMonitor = MockActivityMonitor(idleSeconds: 600)
        let model = try makeModel(
            workInterval: 20 * 60,
            breakDuration: 20,
            activityMonitor: activityMonitor,
            windowCoordinator: coordinator
        )
        let start = Date(timeIntervalSinceReferenceDate: 1_000)

        model.handleAppDidFinishLaunching(now: start)
        XCTAssertEqual(model.appState.countdownText, "20:00")

        model.tick(now: start.addingTimeInterval(1))
        XCTAssertEqual(model.appState.countdownText, "19:59")
    }

    func testIdleResetAppliesAfterActivityWasObserved() throws {
        let coordinator = MockWindowCoordinator()
        let activityMonitor = MockActivityMonitor(idleSeconds: 0)
        let model = try makeModel(
            workInterval: 20 * 60,
            breakDuration: 20,
            activityMonitor: activityMonitor,
            windowCoordinator: coordinator
        )
        let start = Date(timeIntervalSinceReferenceDate: 1_000)

        model.handleAppDidFinishLaunching(now: start)
        model.tick(now: start.addingTimeInterval(1))

        activityMonitor.idleSeconds = 600
        model.tick(now: start.addingTimeInterval(600))

        XCTAssertEqual(model.appState.countdownText, "20:00")
        XCTAssertNil(model.appState.activeBreak)
    }

    func testBreakPhaseCountdownDecreasesEveryTick() throws {
        let coordinator = MockWindowCoordinator()
        let model = try makeModel(
            workInterval: 60,
            breakDuration: 20,
            windowCoordinator: coordinator
        )
        let start = Date(timeIntervalSinceReferenceDate: 1_000)

        model.handleAppDidFinishLaunching(now: start)
        model.tick(now: start.addingTimeInterval(60))

        XCTAssertEqual(model.appState.timerPhase, .breakTime)
        XCTAssertEqual(model.appState.countdownText, "00:20")

        model.tick(now: start.addingTimeInterval(61))
        XCTAssertEqual(model.appState.countdownText, "00:19")
    }

    func testWorkCompletionShowsBreakOverlayFromState() throws {
        let coordinator = MockWindowCoordinator()
        let model = try makeModel(
            workInterval: 60,
            breakDuration: 20,
            windowCoordinator: coordinator
        )
        let start = Date(timeIntervalSinceReferenceDate: 1_000)

        model.handleAppDidFinishLaunching(now: start)
        model.tick(now: start.addingTimeInterval(60))

        XCTAssertNotNil(model.appState.activeBreak)
        XCTAssertEqual(coordinator.showBreakOverlayCalls, 1)
        XCTAssertTrue(coordinator.isBreakOverlayVisible)
    }

    func testHiddenBreakOverlayIsShownAgainOnNextTick() throws {
        let coordinator = MockWindowCoordinator()
        let model = try makeModel(
            workInterval: 60,
            breakDuration: 20,
            windowCoordinator: coordinator
        )
        let start = Date(timeIntervalSinceReferenceDate: 1_000)

        model.handleAppDidFinishLaunching(now: start)
        model.tick(now: start.addingTimeInterval(60))
        coordinator.isBreakOverlayVisible = false

        model.tick(now: start.addingTimeInterval(61))

        XCTAssertEqual(coordinator.showBreakOverlayCalls, 2)
        XCTAssertTrue(coordinator.isBreakOverlayVisible)
    }

    func testNoBreakOverlayAppearsBeforeWorkIntervalElapses() throws {
        let coordinator = MockWindowCoordinator()
        let model = try makeModel(
            workInterval: 60,
            breakDuration: 20,
            windowCoordinator: coordinator
        )
        let start = Date(timeIntervalSinceReferenceDate: 1_000)

        model.handleAppDidFinishLaunching(now: start)
        model.tick(now: start.addingTimeInterval(59))

        XCTAssertNil(model.appState.activeBreak)
        XCTAssertEqual(coordinator.showBreakOverlayCalls, 0)
        XCTAssertFalse(coordinator.isBreakOverlayVisible)
    }

    func testLongTickGapResetsTimerInsteadOfStartingImmediateBreak() throws {
        let coordinator = MockWindowCoordinator()
        let model = try makeModel(
            workInterval: 60,
            breakDuration: 20,
            windowCoordinator: coordinator
        )
        let start = Date(timeIntervalSinceReferenceDate: 1_000)

        model.handleAppDidFinishLaunching(now: start)
        model.tick(now: start.addingTimeInterval(300))

        XCTAssertEqual(model.appState.timerPhase, .work)
        XCTAssertNil(model.appState.activeBreak)
        XCTAssertEqual(model.appState.nextBreakDate, start.addingTimeInterval(360))
        XCTAssertEqual(coordinator.showBreakOverlayCalls, 0)

        for offset in 301..<360 {
            model.tick(now: start.addingTimeInterval(TimeInterval(offset)))
        }
        XCTAssertNil(model.appState.activeBreak)

        model.tick(now: start.addingTimeInterval(360))
        XCTAssertNotNil(model.appState.activeBreak)
        XCTAssertEqual(coordinator.showBreakOverlayCalls, 1)
    }

    private func makeModel(
        workInterval: TimeInterval,
        breakDuration: TimeInterval,
        activityMonitor: MockActivityMonitor = MockActivityMonitor(idleSeconds: 0),
        windowCoordinator: MockWindowCoordinator
    ) throws -> AppModel {
        var settings = completedSettings()
        settings.breakSettings.workInterval = workInterval
        settings.breakSettings.microBreakDuration = breakDuration
        settings.smartPauseSettings.pauseDuringFullscreenFocus = false
        let store = try makeStore(with: settings)

        return AppModel(
            settingsStore: store,
            activityMonitor: activityMonitor,
            windowCoordinator: windowCoordinator,
            launchConfiguration: AppLaunchConfiguration(forceOnboarding: false),
            startsTimer: false,
            observesSystemEvents: false
        )
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
