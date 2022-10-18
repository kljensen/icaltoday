import ArgumentParser
import Contacts
import EventKit
import Foundation

extension EKEvent {
  func isToday() -> Bool {
    let today = Date()
    let calendar = Calendar.current
    let todayComponents = calendar.dateComponents([.year, .month, .day], from: today)
    let eventComponents = calendar.dateComponents([.year, .month, .day], from: self.startDate)
    return todayComponents == eventComponents
  }
  var dateAsString: String {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    return dateFormatter.string(from: self.startDate)
  }
  var calendarItemExternalIdentifierAsBase64: String {
    return Data(self.calendarItemExternalIdentifier.utf8).base64EncodedString()
  }
}

extension EKParticipant {
  var email: String? {
    let emailSelector = "emailAddress"
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

// Description of the code below:
struct SimpleEvent: Codable {
  var name: String
  var attendeeEmails: [String]
  var date: Date
  var uid: String
  var uidAsBase64: String
  var isToday: Bool
  static func fromEKEvent(event: EKEvent) -> SimpleEvent {
    return SimpleEvent(
      name: event.title, attendeeEmails: event.attendees?.compactMap { $0.email } ?? [],
      date: event.startDate, uid: event.calendarItemExternalIdentifier,
      uidAsBase64: event.calendarItemExternalIdentifierAsBase64, isToday: event.isToday()
    )
  }
}

func printEventsAsJSON() {
  let eventStore = EKEventStore()
  eventStore.requestAccess(to: .event) { (granted, error) in
    if let error = error {
      print(error)
      return
    }
  }
  let calendars = eventStore.calendars(for: .event)

  let encoder = JSONEncoder()
  encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
  encoder.dateEncodingStrategy = .iso8601
  for calendar in calendars {
    if calendar.title == "KLJ" {
      let start = Date(timeIntervalSinceNow: -24 * 3600)
      let end = Date(timeIntervalSinceNow: 24 * 3600)
      let predicate = eventStore.predicateForEvents(
        withStart: start, end: end, calendars: [calendar])

      let events = eventStore.events(matching: predicate)

      let meetings = events.map { SimpleEvent.fromEKEvent(event: $0) }
      let data = try! encoder.encode(meetings)
      print(String(data: data, encoding: .utf8)!)
    }
  }
}

@main
struct ICalToday: ParsableCommand {
  static var configuration = CommandConfiguration(
    abstract: "A utility for performing querying calendars and events on Mac OS.",
    subcommands: [Calendars.self, Events.self]
  )
  struct Calendars: ParsableCommand {
    static var configuration = CommandConfiguration(
      abstract: "Calendars subcommand",
      subcommands: [List.self]
    )
    struct List: ParsableCommand {
      static var configuration = CommandConfiguration(
        abstract: "List subcommand"
      )
      mutating func run() throws {
        print("woot")
      }
    }
  }
  struct Events: ParsableCommand {
    static var configuration = CommandConfiguration(
      abstract: "Events subcommand",
      subcommands: [List.self]
    )
    struct List: ParsableCommand {
      static var configuration = CommandConfiguration(
        abstract: "List subcommand"
      )
      mutating func run() throws {
        printEventsAsJSON()
      }
    }
  }

}
