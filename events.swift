#!/usr/bin/swift
import EventKit
import Foundation
import Contacts

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
            for attendee in event.attendees ?? [] {
                print(attendee.email ?? "no email")
            }
        }
    }
}
