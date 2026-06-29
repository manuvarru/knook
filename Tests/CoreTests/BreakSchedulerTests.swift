import Foundation
import Core
import XCTest

final class BreakSchedulerTests: XCTestCase {
    private final class MockPauseConditionProvider: PauseConditionProvider, @unchecked Sendable {
        let name: String
        var isPauseActive: Bool

        init(name: String = "app a schermo intero", isPauseActive: Bool = false) {
            self.name = name
            self.isPauseActive = isPauseActive
        }

        func isPaused(at date: Date) -> Bool {
            _ = date
            return isPauseActive
        }
    }

    func testSchedulerStartsMicroBreakWhenIntervalElapses() {
        let scheduler = BreakScheduler(settings: .default)
        let start = Date(timeIntervalSinceReferenceDate: 1000)

        _ = scheduler.advance(to: start, idleSeconds: 0)
        let snapshot = scheduler.advance(to: start.addingTimeInterval(20 * 60), idleSeconds: 0)

        XCTAssertTrue(snapshot.breakJustStarted)
        XCTAssertEqual(snapshot.state.activeBreak?.kind, .micro)
    }

    func testLongBreakArrivesAfterConfiguredCadence() {
        var settings = AppSettings.default
        settings.breakSettings.workInterval = 60
        settings.breakSettings.microBreakDuration = 10
        settings.breakSettings.longBreakDuration = 120
        settings.breakSettings.longBreakCadence = 2
        let scheduler = BreakScheduler(settings: settings)
        let start = Date(timeIntervalSinceReferenceDate: 1000)

        _ = scheduler.advance(to: start, idleSeconds: 0)
        _ = scheduler.advance(to: start.addingTimeInterval(60), idleSeconds: 0)
        _ = scheduler.advance(to: start.addingTimeInterval(70), idleSeconds: 0)
        _ = scheduler.advance(to: start.addingTimeInterval(130), idleSeconds: 0)
        _ = scheduler.advance(to: start.addingTimeInterval(140), idleSeconds: 0)
        let snapshot = scheduler.advance(to: start.addingTimeInterval(200), idleSeconds: 0)

        XCTAssertEqual(snapshot.state.activeBreak?.kind, .long)
    }

    func testPostponePushesTheNextBreakOut() {
        var settings = AppSettings.default
        settings.breakSettings.workInterval = 60
        let scheduler = BreakScheduler(settings: settings)
        let start = Date(timeIntervalSinceReferenceDate: 1000)

        _ = scheduler.advance(to: start, idleSeconds: 0)
        let postponed = scheduler.postpone(minutes: 5, now: start.addingTimeInterval(30))

        XCTAssertEqual(postponed.state.nextBreakDate, start.addingTimeInterval(360))
    }

    func testHardcoreModePreventsSkippingActiveBreaks() {
        var settings = AppSettings.default
        settings.breakSettings.workInterval = 60
        settings.breakSettings.skipPolicy = .hardcore
        let scheduler = BreakScheduler(settings: settings)
        let start = Date(timeIntervalSinceReferenceDate: 1000)

        _ = scheduler.advance(to: start, idleSeconds: 0)
        _ = scheduler.advance(to: start.addingTimeInterval(60), idleSeconds: 0)
        let skipped = scheduler.skipCurrentBreak(at: start.addingTimeInterval(61))

        XCTAssertNotNil(skipped.state.activeBreak)
    }

    func testSchedulerResetsAfterUserIsIdle() {
        var settings = AppSettings.default
        settings.breakSettings.workInterval = 60
        settings.scheduleSettings.idleResetThreshold = 120
        let scheduler = BreakScheduler(settings: settings)
        let start = Date(timeIntervalSinceReferenceDate: 1000)

        _ = scheduler.advance(to: start, idleSeconds: 0)
        let snapshot = scheduler.advance(to: start.addingTimeInterval(30), idleSeconds: 180)

        XCTAssertEqual(snapshot.state.nextBreakDate, start.addingTimeInterval(90))
        XCTAssertNil(snapshot.state.activeBreak)
    }

    func testOfficeHoursBlockBreaksOutsideSchedule() {
        var settings = AppSettings.default
        settings.breakSettings.workInterval = 60
        settings.scheduleSettings.officeHours = [
            OfficeHoursRule(weekday: 2, startMinutes: 9 * 60, endMinutes: 10 * 60),
        ]

        let calendar = Calendar(identifier: .gregorian)
        let scheduler = BreakScheduler(settings: settings, calendar: calendar)
        let outside = calendar.date(from: DateComponents(year: 2026, month: 3, day: 28, hour: 11, minute: 0))!
        let snapshot = scheduler.advance(to: outside, idleSeconds: 0)

        XCTAssertNil(snapshot.state.nextBreakDate)
        XCTAssertEqual(snapshot.state.statusText, "Fuori dall'orario di lavoro")
    }

    @MainActor
    func testSmartPauseSuppressesBreakWhileProviderIsActive() {
        var settings = AppSettings.default
        settings.breakSettings.workInterval = 120
        let provider = MockPauseConditionProvider(isPauseActive: true)
        let scheduler = BreakScheduler(settings: settings, pauseProviders: [provider])
        let start = Date(timeIntervalSinceReferenceDate: 1_000)

        _ = scheduler.advance(to: start, idleSeconds: 0)
        let pausedSnapshot = scheduler.advance(to: start.addingTimeInterval(80), idleSeconds: 0)
        let pausedBreak = scheduler.advance(to: start.addingTimeInterval(140), idleSeconds: 0)

        XCTAssertTrue(pausedSnapshot.state.isPaused)
        XCTAssertEqual(pausedSnapshot.state.pauseReason, "app a schermo intero")
        XCTAssertNil(pausedBreak.state.activeBreak)
        XCTAssertFalse(pausedBreak.breakJustStarted)
    }

    @MainActor
    func testManualPauseResumePreservesRemainingTime() {
        var settings = AppSettings.default
        settings.breakSettings.workInterval = 120
        let scheduler = BreakScheduler(settings: settings)
        let start = Date(timeIntervalSinceReferenceDate: 1_000)

        _ = scheduler.advance(to: start, idleSeconds: 0)
        // Metti in pausa 40 secondi dentro l'intervallo da 120 secondi (80s rimanenti).
        _ = scheduler.pause(reason: "In pausa manualmente", now: start.addingTimeInterval(40))
        // Riprendi 30 secondi dopo.
        let resumed = scheduler.resume(now: start.addingTimeInterval(70))

        // Dovrebbero restare 80s dal momento della ripresa: pausa a start+150.
        XCTAssertEqual(resumed.state.nextBreakDate, start.addingTimeInterval(150))
        XCTAssertFalse(resumed.state.isPaused)
    }

    func testSmartPauseResumeRestoresRemainingTimeWithoutImmediateBreak() {
        var settings = AppSettings.default
        settings.breakSettings.workInterval = 120
        let provider = MockPauseConditionProvider(isPauseActive: false)
        let scheduler = BreakScheduler(settings: settings, pauseProviders: [provider])
        let start = Date(timeIntervalSinceReferenceDate: 1_000)

        _ = scheduler.advance(to: start, idleSeconds: 0)
        provider.isPauseActive = true
        _ = scheduler.advance(to: start.addingTimeInterval(40), idleSeconds: 0)

        provider.isPauseActive = false
        let resumed = scheduler.advance(to: start.addingTimeInterval(80), idleSeconds: 0)
        let activeTooSoon = scheduler.advance(to: start.addingTimeInterval(159), idleSeconds: 0)
        let breakStarts = scheduler.advance(to: start.addingTimeInterval(160), idleSeconds: 0)

        XCTAssertFalse(resumed.state.isPaused)
        XCTAssertEqual(resumed.state.nextBreakDate, start.addingTimeInterval(160))
        XCTAssertNil(activeTooSoon.state.activeBreak)
        XCTAssertTrue(breakStarts.breakJustStarted)
    }

    @MainActor
    func testSmartPauseOverdueResumeGetsTwoMinuteGracePeriod() {
        var settings = AppSettings.default
        settings.breakSettings.workInterval = 120
        let provider = MockPauseConditionProvider(isPauseActive: false)
        let scheduler = BreakScheduler(settings: settings, pauseProviders: [provider])
        let start = Date(timeIntervalSinceReferenceDate: 1_000)

        _ = scheduler.advance(to: start, idleSeconds: 0)
        provider.isPauseActive = true
        _ = scheduler.advance(to: start.addingTimeInterval(90), idleSeconds: 0)

        provider.isPauseActive = false
        let resumed = scheduler.advance(to: start.addingTimeInterval(200), idleSeconds: 0)
        let stillWaiting = scheduler.advance(to: start.addingTimeInterval(319), idleSeconds: 0)
        let breakStarts = scheduler.advance(to: start.addingTimeInterval(320), idleSeconds: 0)

        XCTAssertEqual(resumed.state.nextBreakDate, start.addingTimeInterval(320))
        XCTAssertNil(stillWaiting.state.activeBreak)
        XCTAssertTrue(breakStarts.breakJustStarted)
    }
}
