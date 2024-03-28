import XCTest
@testable import icaltoday

final class icaltodayTests: XCTestCase {
    func testparseTimeRange() {
        // Tests the parseTimeRange function in the icaltoday module
        let timeRange = parseTimeRange("10:00-11:00")
        print(timeRange!.1)
        // Assert that we didn't get back nil
        XCTAssertNotNil(timeRange)
        // Test at the first element of the tuple has a time of 10:00.
        // It is a Date object, so we need to convert it to a string to compare it.
        XCTAssertEqual(timeRange!.0.description, "2000-01-01 10:00:00 +0000")
        XCTAssertEqual(timeRange!.1.description, "2000-01-01 11:00:00 +0000")

        // Try an invalid time range
        let invalidTimeRange = parseTimeRange("10:00-")
        XCTAssertNil(invalidTimeRange)

    }
}
