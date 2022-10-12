#!/usr/bin/swift
import EventKit
import Foundation
import Contacts

let eventStore = EKEventStore()
eventStore.requestAccess(to: .event) { (granted, error) in
    if let error = error {
       print(error)
       return
    }
}

private let emailSelector = "emailAddress"
extension EKParticipant {
  var email: String? {
    if responds(to: Selector(emailSelector)) {
      return value(forKey: emailSelector) as? String
    }

    let emailComponents = description.components(separatedBy: "email = ")
    if emailComponents.count > 1 {
      return emailComponents[1].components(separatedBy: ";")[0]
    }

    if let email = (url as NSURL).resourceSpecifier, !email.hasPrefix("/") {
      return email
    }

    return nil
  }
}

var titles : [String] = []
var startDates : [Date] = []
var endDates : [Date] = []


let calendars = eventStore.calendars(for: .event)

for calendar in calendars {
    print("hey")
    if calendar.title == "KLJ" {
        print("woot")
        let start = Date(timeIntervalSinceNow: -24*3600)
        let end = Date(timeIntervalSinceNow: 24*3600)
        let predicate =  eventStore.predicateForEvents(withStart: start, end: end, calendars: [calendar])
        
        let events = eventStore.events(matching: predicate)
        
        for event in events {
            titles.append(event.title)
            startDates.append(event.startDate)
            endDates.append(event.endDate)
            print(event.title ?? "no title")
            for attendee in event.attendees ?? [] {
                print(attendee.email ?? "no email")
            }
        }
    }
}
