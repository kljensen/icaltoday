import XCTest
import EventKit
@testable import icaltoday

// A little helper for making EKEvents tersely
func makeEvent(start: Date, end: Date) -> EKEvent {
    let event = EKEvent( eventStore: EKEventStore())
    event.startDate = start
    event.endDate = end
    return event
}

// Same as above but takes seconds since 1970
func makeEvent(start: TimeInterval, end: TimeInterval) -> EKEvent {
    return makeEvent(start: Date(timeIntervalSince1970: start), end: Date(timeIntervalSince1970: end))
}

final class icaltodayTests: XCTestCase {
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
    func testCompareEvents() {
        let event1 = makeEvent(start: 0, end: 10)
        let event2 = makeEvent(start: 5, end: 15)
        let event3 = makeEvent(start: 20, end: 30)
        let event4 = makeEvent(start: 25, end: 35)
        let event5 = makeEvent(start: 40, end: 50)
        let event6 = makeEvent(start: 20, end: 60)
        
        XCTAssertEqual(event1.compare(to: event1), .same)
        XCTAssertEqual(event1.compare(to: event2), .overlapsAtStart)
        XCTAssertEqual(event1.compare(to: event3), .before)
        XCTAssertEqual(event1.compare(to: event4), .before)
        XCTAssertEqual(event1.compare(to: event5), .before)
        XCTAssertEqual(event1.compare(to: event6), .before)
        
        XCTAssertEqual(event2.compare(to: event1), .overlapsAtEnd)
        XCTAssertEqual(event2.compare(to: event2), .same)
        XCTAssertEqual(event2.compare(to: event3), .before)
        XCTAssertEqual(event2.compare(to: event4), .before)
        XCTAssertEqual(event2.compare(to: event5), .before)
        XCTAssertEqual(event2.compare(to: event6), .before)
        
        XCTAssertEqual(event3.compare(to: event1), .after)
        XCTAssertEqual(event3.compare(to: event2), .after)
        XCTAssertEqual(event3.compare(to: event3), .same)
        XCTAssertEqual(event3.compare(to: event4), .overlapsAtStart)
        XCTAssertEqual(event3.compare(to: event5), .before)
        XCTAssertEqual(event3.compare(to: event6), .overlapsAtStart)
        
        XCTAssertEqual(event4.compare(to: event1), .after)
        XCTAssertEqual(event4.compare(to: event2), .after)
        XCTAssertEqual(event4.compare(to: event3), .overlapsAtEnd)
        XCTAssertEqual(event4.compare(to: event4), .same)
        XCTAssertEqual(event4.compare(to: event5), .before)
        XCTAssertEqual(event4.compare(to: event6), .within)

        XCTAssertEqual(event5.compare(to: event1), .after)
        XCTAssertEqual(event5.compare(to: event2), .after)
        XCTAssertEqual(event5.compare(to: event3), .after)
        XCTAssertEqual(event5.compare(to: event4), .after)
        XCTAssertEqual(event5.compare(to: event5), .same)
        XCTAssertEqual(event5.compare(to: event6), .within)

        XCTAssertEqual(event6.compare(to: event1), .after)
        XCTAssertEqual(event6.compare(to: event2), .after)
        XCTAssertEqual(event6.compare(to: event3), .encompasses)
        XCTAssertEqual(event6.compare(to: event4), .encompasses)
        XCTAssertEqual(event6.compare(to: event5), .encompasses)
        XCTAssertEqual(event6.compare(to: event6), .same)
    }

    func testSubtractEvents() {
        let event1 = makeEvent(start: 0, end: 10)
        let event3 = makeEvent(start: 20, end: 30)
        let event4 = makeEvent(start: 25, end: 35)
        let event5 = makeEvent(start: 10, end: 50)
        let event6 = makeEvent(start: 10, end: 40)
        
        // Test case 1: Same events
        XCTAssertEqual(event1.subtract(event1), [])
        
        // Test case 2: Event is before otherEvent
        XCTAssertEqual(event1.subtract(event3), [event1])
        
        // Test case 3: Event is after otherEvent
        XCTAssertEqual(event3.subtract(event1), [event3])
        
        // Test case 4: Subtracted event overlaps at end
        let subtractedEvents4 = event3.subtract(event4)
        XCTAssertEqual(subtractedEvents4.count, 1)
        XCTAssertEqual(subtractedEvents4[0].startDate, event3.startDate)
        XCTAssertEqual(subtractedEvents4[0].endDate, event4.startDate)
        
        // Test case 5: Event overlaps at end of otherEvent
        let subtractedEvents5 = event4.subtract(event3)
        XCTAssertEqual(subtractedEvents5.count, 1)
        XCTAssertEqual(subtractedEvents5[0].startDate, event3.endDate)
        XCTAssertEqual(subtractedEvents5[0].endDate, event4.endDate)
        
        // Test case 6: Event is within otherEvent
        XCTAssertEqual(event3.subtract(event5), [])
        
        // Test case 7: Event encompasses otherEvent
        let subtractedEvents7 = event5.subtract(event3)
        XCTAssertEqual(subtractedEvents7.count, 2)
        XCTAssertEqual(subtractedEvents7[0].startDate, event5.startDate)
        XCTAssertEqual(subtractedEvents7[0].endDate, event3.startDate)
        XCTAssertEqual(subtractedEvents7[1].startDate, event3.endDate)
        XCTAssertEqual(subtractedEvents7[1].endDate, event5.endDate)

        let subtractedEvents8 = event5.subtract(event6)
        XCTAssertEqual(subtractedEvents8.count, 1)
    }

    func testSubtractListOfEvents() {
        let possiblePeriod = makeEvent(start: 0, end: 100)
        let busy10to20 = makeEvent(start: 10, end: 20)
        let busy20to30 = makeEvent(start: 20, end: 30)
        let busy30to40 = makeEvent(start: 30, end: 40)
        let busy50to100 = makeEvent(start: 50, end: 100)
        let busy0to50 = makeEvent(start: 0, end: 50)
        // let busy50to60 = makeEvent(start: 50, end: 60)

        // Test case 1: Subtracting a list of events from a period
        let avail1 = possiblePeriod.subtract([busy10to20])
        XCTAssertEqual(avail1.count, 2)
        XCTAssertEqual(avail1[0].startDate, possiblePeriod.startDate)
        XCTAssertEqual(avail1[0].endDate, busy10to20.startDate)
        XCTAssertEqual(avail1[1].startDate, busy10to20.endDate)
        XCTAssertEqual(avail1[1].endDate, possiblePeriod.endDate)

        let avail2 = possiblePeriod.subtract([busy10to20, busy20to30])
        XCTAssertEqual(avail2.count, 2)
        XCTAssertEqual(avail2[0].startDate, possiblePeriod.startDate)
        XCTAssertEqual(avail2[0].endDate, busy10to20.startDate)
        XCTAssertEqual(avail2[1].startDate, busy20to30.endDate)
        XCTAssertEqual(avail2[1].endDate, possiblePeriod.endDate)

        let avail3 = possiblePeriod.subtract([busy10to20, busy30to40])
        XCTAssertEqual(avail3.count, 3)
        XCTAssertEqual(avail3[0].startDate, possiblePeriod.startDate)
        XCTAssertEqual(avail3[0].endDate, busy10to20.startDate)
        XCTAssertEqual(avail3[1].startDate, busy10to20.endDate)
        XCTAssertEqual(avail3[1].endDate, busy30to40.startDate)
        XCTAssertEqual(avail3[2].startDate, busy30to40.endDate)
        XCTAssertEqual(avail3[2].endDate, possiblePeriod.endDate)

        let avail4 = possiblePeriod.subtract([busy0to50])
        XCTAssertEqual(avail4.count, 1)
        XCTAssertEqual(avail4[0].startDate, busy0to50.endDate)
        XCTAssertEqual(avail4[0].endDate, possiblePeriod.endDate)

        let avail5 = possiblePeriod.subtract([busy50to100])
        XCTAssertEqual(avail5.count, 1)
        XCTAssertEqual(avail5[0].startDate, possiblePeriod.startDate)
        XCTAssertEqual(avail5[0].endDate, busy50to100.startDate)

        let avail6 = possiblePeriod.subtract([busy0to50, busy50to100])
        XCTAssertEqual(avail6.count, 0)
        

    }

}

func testTimeOfDayToString() {
    // Test case 1: Valid time
    let time1 = TimeOfDay(hour: 10, minute: 30)
    XCTAssertEqual(time1?.toString(), "10:30")
    
    // Test case 2: Time with single digit hour and minute
    let time2 = TimeOfDay(hour: 5, minute: 5)
    XCTAssertEqual(time2?.toString(), "05:05")
    
    // Test case 3: Time with leading zero hour and minute
    let time3 = TimeOfDay(hour: 0, minute: 0)
    XCTAssertEqual(time3?.toString(), "00:00")
}

func testTimeOfDayToDateComponents() {
    // Test case 1: Valid time
    let time1 = TimeOfDay(hour: 10, minute: 30)
    let dateComponents1 = time1?.toDateComponents()
    XCTAssertEqual(dateComponents1?.hour, 10)
    XCTAssertEqual(dateComponents1?.minute, 30)
    
    // Test case 2: Time with single digit hour and minute
    let time2 = TimeOfDay(hour: 5, minute: 5)
    let dateComponents2 = time2?.toDateComponents()
    XCTAssertEqual(dateComponents2?.hour, 5)
    XCTAssertEqual(dateComponents2?.minute, 5)
    
    // Test case 3: Time with leading zero hour and minute
    let time3 = TimeOfDay(hour: 0, minute: 0)
    let dateComponents3 = time3?.toDateComponents()
    XCTAssertEqual(dateComponents3?.hour, 0)
    XCTAssertEqual(dateComponents3?.minute, 0)
}

func testTimeOfDayInitFromString() {
    // Test case 1: Valid time string
    let time1 = TimeOfDay(fromString: "10:30")
    XCTAssertEqual(time1?.hour, 10)
    XCTAssertEqual(time1?.minute, 30)
    
    // Test case 2: Time string with single digit hour and minute
    let time2 = TimeOfDay(fromString: "5:5")
    XCTAssertEqual(time2?.hour, 5)
    XCTAssertEqual(time2?.minute, 5)
    
    // Test case 3: Time string with leading zero hour and minute
    let time3 = TimeOfDay(fromString: "00:00")
    XCTAssertEqual(time3?.hour, 0)
    XCTAssertEqual(time3?.minute, 0)
    
    // Test case 4: Invalid time string
    let time4 = TimeOfDay(fromString: "10:30:00")
    XCTAssertNil(time4)
}

func testTimeOfDayInit() {
    // Test case 1: Valid time
    let time1 = TimeOfDay(hour: 10, minute: 30)
    XCTAssertEqual(time1?.hour, 10)
    XCTAssertEqual(time1?.minute, 30)
    
    // Test case 2: Invalid hour
    let time2 = TimeOfDay(hour: 24, minute: 30)
    XCTAssertNil(time2)
    
    // Test case 3: Invalid minute
    let time3 = TimeOfDay(hour: 10, minute: 60)
    XCTAssertNil(time3)
}

func testGetTimeBlockEvents() {
    let startDate = Date()
    let endDate = Calendar.current.date(byAdding: .day, value: 7, to: startDate)!
    let startTime = TimeOfDay(hour: 9, minute: 0)!
    let endTime = TimeOfDay(hour: 17, minute: 0)!
    
    let availabilityEvents = getTimeBlockEvents(startDate: startDate, endDate: endDate, startTime: startTime, endTime: endTime)
    
    XCTAssertEqual(availabilityEvents.count, 8)
    
    for event in availabilityEvents {
        XCTAssertEqual(event.startDate, Calendar.current.date(bySettingHour: startTime.hour, minute: startTime.minute, second: 0, of: event.startDate))
        XCTAssertEqual(event.endDate, Calendar.current.date(bySettingHour: endTime.hour, minute: endTime.minute, second: 0, of: event.endDate))
    }
}