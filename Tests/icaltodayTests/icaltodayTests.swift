import XCTest
import EventKit
@testable import icaltoday

// A little helper for making EKEvents tersely
func makeEvent(start: Date, end: Date) -> EKEvent {
    let event = EKEvent(eventStore: EKEventStore())
    event.startDate = start
    event.endDate = end
    return event
}

// Same as above but takes seconds since 1970
func makeEvent(start: TimeInterval, end: TimeInterval) -> EKEvent {
    return makeEvent(start: Date(timeIntervalSince1970: start), end: Date(timeIntervalSince1970: end))
}

final class icaltodayTests: XCTestCase {
    func testparseTimeRange() {
        // Tests the parseTimeRange function in the icaltoday module
        let timeRange = parseTimeRange("10:00-11:00")
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
    func testSortEventsByStartDate(){
        let numEvents = 10
        var events = [EKEvent]()
        for _ in 0..<numEvents {
            let event = EKEvent(eventStore: EKEventStore())
            // Choose a random start date
            event.startDate = Date(timeIntervalSince1970: TimeInterval.random(in: 0...100000000))
            events.append(event)
        }
        // Sort the events
        let sortedEvents = sortEventsByStartDate(events)
        // Loop over and check that the events are sorted
        for i in 0..<sortedEvents.count-1 {
            XCTAssertLessThan(sortedEvents[i].startDate, sortedEvents[i+1].startDate)
        }
    }

    func testMergeOverlappingEvents1(){
        let events = [
            makeEvent(start: 0, end: 10),
            makeEvent(start: 5, end: 15),
            makeEvent(start: 20, end: 30),
            makeEvent(start: 25, end: 35),
            makeEvent(start: 40, end: 50),
            makeEvent(start: 45, end: 55),
        ]
        let mergedEvents  = mergeOverlappingEvents(events)
        XCTAssertEqual(mergedEvents.count, 3)
    }
    func testMergeOverlappingEvents2(){
        let events = [
            makeEvent(start: 0, end: 10),
            makeEvent(start: 5, end: 15),
            makeEvent(start: 20, end: 30),
            makeEvent(start: 25, end: 35),
            makeEvent(start: 40, end: 50),
            makeEvent(start: 0, end: 55),
        ]
        let mergedEvents  = mergeOverlappingEvents(events)
        XCTAssertEqual(mergedEvents.count, 1)
    }
    func testMergeOverlappingEvents3(){
        let events = [
            makeEvent(start: 0, end: 10),
            makeEvent(start: 5, end: 15),
            makeEvent(start: 20, end: 30),
            makeEvent(start: 25, end: 35),
            makeEvent(start: 35, end: 50),
        ]
        let mergedEvents  = mergeOverlappingEvents(events)
        XCTAssertEqual(mergedEvents.count, 2)
    }
}
func testCompareEvents() {
    let event1 = makeEvent(start: 0, end: 10)
    let event2 = makeEvent(start: 5, end: 15)
    let event3 = makeEvent(start: 20, end: 30)
    let event4 = makeEvent(start: 25, end: 35)
    let event5 = makeEvent(start: 40, end: 50)
    
    XCTAssertEqual(event1.compare(to: event2), .overlapsAtStart)
    XCTAssertEqual(event1.compare(to: event3), .before)
    XCTAssertEqual(event1.compare(to: event4), .overlapsAtStart)
    XCTAssertEqual(event1.compare(to: event5), .before)
    
    XCTAssertEqual(event2.compare(to: event1), .overlapsAtStart)
    XCTAssertEqual(event2.compare(to: event3), .overlapsAtEnd)
    XCTAssertEqual(event2.compare(to: event4), .overlapsAtEnd)
    XCTAssertEqual(event2.compare(to: event5), .before)
    
    XCTAssertEqual(event3.compare(to: event1), .after)
    XCTAssertEqual(event3.compare(to: event2), .overlapsAtEnd)
    XCTAssertEqual(event3.compare(to: event4), .overlapsAtStart)
    XCTAssertEqual(event3.compare(to: event5), .before)
    
    XCTAssertEqual(event4.compare(to: event1), .overlapsAtStart)
    XCTAssertEqual(event4.compare(to: event2), .overlapsAtEnd)
    XCTAssertEqual(event4.compare(to: event3), .overlapsAtStart)
    XCTAssertEqual(event4.compare(to: event5), .before)
    
    XCTAssertEqual(event5.compare(to: event1), .after)
    XCTAssertEqual(event5.compare(to: event2), .after)
    XCTAssertEqual(event5.compare(to: event3), .after)
    XCTAssertEqual(event5.compare(to: event4), .after)
}