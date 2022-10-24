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

func getMatchingCalendars(eventStore: EKEventStore, calendarNames: [String]?) -> [EKCalendar] {
  let calendars = eventStore.calendars(for: .event)
  if let calendarNames = calendarNames {
    if calendarNames.count == 0 {
      return calendars
    }
    return calendars.filter { calendarNames.contains($0.title) }
  } else {
    return calendars
  }
}

func printEventsAsJSON(withEventStore eventStore: EKEventStore, withCalendars calendars: [EKCalendar], withStart startDate: Date, withEnd endDate: Date) {
  if calendars == [] {
    print("{}")
    return
  }
  let predicate = eventStore.predicateForEvents(
    withStart: startDate, end: endDate, calendars: calendars
  )
  let events = eventStore.events(matching: predicate)
  let meetings = events.map { SimpleEvent.fromEKEvent(event: $0) }

  // Print the events as JSON
  let encoder = JSONEncoder()
  encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
  encoder.dateEncodingStrategy = .iso8601
  let data = try! encoder.encode(meetings)
  print(String(data: data, encoding: .utf8)!)
}

// A function that takes a string and returns
// an optional Date. It tries to parse the string
// into a date using a few common formats. The
// time zone is set to local time.
func parseDate(_ dateString: String) -> Date? {
  let dateFormatter = DateFormatter()
  dateFormatter.dateFormat = "yyyy-MM-dd"
  dateFormatter.timeZone = TimeZone.current
  if let date = dateFormatter.date(from: dateString) {
    return date
  }
  dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
  if let date = dateFormatter.date(from: dateString) {
    return date
  }
  dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
  if let date = dateFormatter.date(from: dateString) {
    return date
  }
  return nil
}


// Extend Date to make so that we can
// make dates from strings.
extension Date: ExpressibleByArgument {
  public init?(argument: String) {
    if let date = parseDate(argument) {
      self = date
    } else {
      return nil
    }
  }  
}

func listAllCalendarsAsJSON(withEventStore eventStore: EKEventStore) {
  let calendars = eventStore.calendars(for: .event)
  let encoder = JSONEncoder()
  encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
  encoder.dateEncodingStrategy = .iso8601
  let calendarNames = calendars.map { $0.title }
  let data = try! encoder.encode(calendarNames)
  print(String(data: data, encoding: .utf8)!)
}


@main
struct icaltoday: ParsableCommand {
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
        let eventStore = EKEventStore()
        eventStore .requestAccess(to: .event) { (granted, error) in
          if let error = error {
            print(error)
            return
          }
        }
        listAllCalendarsAsJSON(withEventStore: eventStore)
      }
    }
  }
  struct Events: ParsableCommand {
    static var configuration = CommandConfiguration(
      abstract: "Events subcommand",
      subcommands: [List.self]
    )
    struct List: ParsableCommand {
      @Argument
      var startDate: Date
      @Argument
      var endDate: Date
      @Option(name: [.short, .customLong("calendar")])
      var calendarNames: [String] = []

      static var configuration = CommandConfiguration(
        abstract: "List subcommand"
      )
      mutating func run() throws {
        let eventStore = EKEventStore()
        eventStore .requestAccess(to: .event) { (granted, error) in
          if let error = error {
            print(error)
            return
          }
        }
        let calendars = getMatchingCalendars(eventStore: eventStore, calendarNames: calendarNames)
        printEventsAsJSON(withEventStore: eventStore, withCalendars: calendars, withStart: startDate, withEnd: endDate)
      }
    }
  }

}

