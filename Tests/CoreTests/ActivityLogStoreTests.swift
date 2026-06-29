import Foundation
@testable import Core
import XCTest

final class ActivityLogStoreTests: XCTestCase {
    private func makeTempStore(minimumSamples: Int = 5) -> ActivityLogStore {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let url = dir.appendingPathComponent("activity-log.json")
        return ActivityLogStore(fileURL: url, minimumSamples: minimumSamples)
    }

    func testDefaultFileURLUsesItalianForkDirectory() {
        XCTAssertEqual(ActivityLogStore.defaultFileURL.lastPathComponent, "activity-log.json")
        XCTAssertEqual(ActivityLogStore.defaultFileURL.deletingLastPathComponent().lastPathComponent, "knook-ita")
    }

    private func makeDate(weekday: Int, hour: Int, dayOffset: Int = 0) -> Date {
        var calendar = Calendar.current
        calendar.firstWeekday = 1
        var components = DateComponents()
        components.year = 2026
        components.month = 4
        components.weekday = weekday
        components.weekdayOrdinal = 1 + dayOffset
        components.hour = hour
        components.minute = 0
        return calendar.date(from: components)!
    }

    func testRecordActivityMarksHourForWeekday() {
        let store = makeTempStore()
        let monday9am = makeDate(weekday: 2, hour: 9)

        store.recordActivity(at: monday9am)

        let log = store.load()
        let mondayLog = log.weekdayLogs.first { $0.weekday == 2 }
        XCTAssertNotNil(mondayLog)
        XCTAssertTrue(mondayLog!.activeHours.contains(9))
        XCTAssertEqual(mondayLog!.sampleCount, 1)
    }

    func testSameHourSameDayDoesNotDuplicateOrIncrementSample() {
        let store = makeTempStore()
        let monday9am = makeDate(weekday: 2, hour: 9)

        store.recordActivity(at: monday9am)
        store.recordActivity(at: monday9am)

        let log = store.load()
        let mondayLog = log.weekdayLogs.first { $0.weekday == 2 }!
        XCTAssertEqual(mondayLog.activeHours.count, 1)
        XCTAssertEqual(mondayLog.sampleCount, 1)
    }

    func testSuggestedOfficeHoursEmptyWhenNotEnoughSamples() {
        let store = makeTempStore(minimumSamples: 5)
        let monday9am = makeDate(weekday: 2, hour: 9)

        store.recordActivity(at: monday9am)

        let suggestions = store.suggestedOfficeHours()
        XCTAssertTrue(suggestions.isEmpty)
    }

    func testSuggestedOfficeHoursAfterEnoughData() {
        let store = makeTempStore(minimumSamples: 2)

        let day1 = makeDate(weekday: 2, hour: 9, dayOffset: 0)
        let day2 = makeDate(weekday: 2, hour: 9, dayOffset: 1)

        store.recordActivity(at: day1)
        store.recordActivity(at: day2)

        // Also add an afternoon hour
        let calendar = Calendar.current
        let afternoon = calendar.date(bySettingHour: 17, minute: 0, second: 0, of: day1)!
        store.recordActivity(at: afternoon)

        let suggestions = store.suggestedOfficeHours()
        XCTAssertEqual(suggestions.count, 1)

        let rule = suggestions[0]
        XCTAssertEqual(rule.weekday, 2)
        XCTAssertEqual(rule.startMinutes, 9 * 60)
        XCTAssertEqual(rule.endMinutes, 18 * 60)
    }

    func testHasEnoughDataReturnsFalseInitially() {
        let store = makeTempStore()
        XCTAssertFalse(store.hasEnoughData())
    }

    func testPersistenceRoundTrip() {
        let store = makeTempStore()
        let date = makeDate(weekday: 3, hour: 10)

        store.recordActivity(at: date)

        let reloaded = store.load()
        XCTAssertEqual(reloaded.weekdayLogs.count, 1)
        XCTAssertTrue(reloaded.weekdayLogs[0].activeHours.contains(10))
    }

    func testLoadMigratesFromLegacyFileLocationWhenPrimaryFileIsMissing() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let newFileURL = directory
            .appendingPathComponent("knook-ita", isDirectory: true)
            .appendingPathComponent("activity-log.json", isDirectory: false)
        let legacyFileURL = directory
            .appendingPathComponent("knook", isDirectory: true)
            .appendingPathComponent("activity-log.json", isDirectory: false)

        let legacyLog = ActivityLogData(
            weekdayLogs: [WeekdayActivityLog(weekday: 2, activeHours: [9, 10], sampleCount: 6)],
            lastRecordedDate: "2026-04-01"
        )

        try FileManager.default.createDirectory(
            at: legacyFileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try JSONEncoder().encode(legacyLog).write(to: legacyFileURL)

        let store = ActivityLogStore(fileURL: newFileURL, legacyFileURLs: [legacyFileURL])
        let loaded = store.load()

        XCTAssertEqual(loaded.weekdayLogs.first?.weekday, 2)
        XCTAssertEqual(loaded.weekdayLogs.first?.sampleCount, 6)
        XCTAssertTrue(loaded.weekdayLogs.first?.activeHours.contains(10) == true)
        XCTAssertTrue(FileManager.default.fileExists(atPath: newFileURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: legacyFileURL.path))
    }
}
