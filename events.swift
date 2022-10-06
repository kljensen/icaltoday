import EventKit

var titles : [String] = []
var startDates : [Date] = []
var endDates : [Date] = []

var store = EKEventStore()

let calendars = store.calendars(for: .event)

for calendar in calendars {
    if calendar.title == "KLJ" {
        print("woot")
        let start = Date(timeIntervalSinceNow: -24*3600)
        let end = Date(timeIntervalSinceNow: 24*3600)
        let predicate =  store.predicateForEvents(withStart: start, end: end, calendars: [calendar])
        
        let events = store.events(matching: predicate)
        
        for event in events {
            titles.append(event.title)
            startDates.append(event.startDate)
            endDates.append(event.endDate)
            print(event.title ?? "no title")
        }
    }
}
