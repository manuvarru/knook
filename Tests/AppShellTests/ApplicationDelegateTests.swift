@testable import AppShell
import Core
import XCTest

@MainActor
final class ApplicationDelegateTests: XCTestCase {
    func testUsesRuntimeIconOutsideAppBundle() {
        let bundleURL = URL(fileURLWithPath: "/tmp/knook", isDirectory: true)

        XCTAssertTrue(ApplicationDelegate.shouldApplyRuntimeIcon(bundleURL: bundleURL))
    }

    func testSkipsRuntimeIconInsideAppBundle() {
        let bundleURL = URL(fileURLWithPath: "/Applications/knook.app", isDirectory: true)

        XCTAssertFalse(ApplicationDelegate.shouldApplyRuntimeIcon(bundleURL: bundleURL))
    }

    func testUsesInjectedModelInstance() {
        let updateManager = NullUpdateManager()
        let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }
        let store = SettingsStore(fileURL: directory.appendingPathComponent("settings.json"))
        try? store.save(.default)
        let model = AppModel(
            settingsStore: store,
            updateManager: updateManager,
            startsTimer: false,
            observesSystemEvents: false
        )

        let delegate = ApplicationDelegate(model: model, updateManager: updateManager)

        XCTAssertTrue(delegate.model === model)
    }

    func testAllowsTerminationWhenNoBreakIsActive() {
        let delegate = makeDelegate()

        XCTAssertEqual(delegate.applicationShouldTerminate(NSApplication.shared), .terminateNow)
    }

    func testBlocksTerminationDuringActiveBreak() {
        let delegate = makeDelegate()
        let now = Date()
        delegate.model.appState = AppState(
            now: now,
            nextBreakDate: nil,
            activeBreak: BreakSession(
                kind: .micro,
                startedAt: now,
                scheduledEnd: now.addingTimeInterval(20),
                message: "Pausa",
                backgroundStyle: .dawn,
                skipAvailableAfter: nil
            ),
            isPaused: false,
            pauseReason: nil,
            statusText: "Pausa breve"
        )

        XCTAssertEqual(delegate.applicationShouldTerminate(NSApplication.shared), .terminateCancel)
    }

    private func makeDelegate() -> ApplicationDelegate {
        let updateManager = NullUpdateManager()
        let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }
        let store = SettingsStore(fileURL: directory.appendingPathComponent("settings.json"))
        try? store.save(.default)
        let model = AppModel(
            settingsStore: store,
            updateManager: updateManager,
            startsTimer: false,
            observesSystemEvents: false
        )
        return ApplicationDelegate(model: model, updateManager: updateManager)
    }
}
