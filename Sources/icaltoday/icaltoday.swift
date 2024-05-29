import ArgumentParser
import Contacts
import EventKit
import Foundation

// Assuming EventComparisonResult enum is defined as previously discussed
enum EventComparisonResult {
    case same
    case before
    case after
    // The first event begins before the second event and ends within it
    case overlapsAtStart
    // The first event begins within the second event and ends after it
    case overlapsAtEnd
    // The first event is completely within the second event
    case within
    case encompasses
}
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
  /// Compares this event with another event to determine their temporal relationship.
  /// - Parameter event: The other `EKEvent` instance to compare against.
  /// - Returns: An `EventComparisonResult` indicating how the events compare.
  func compare(to event: EKEvent) -> EventComparisonResult {
      guard let thisStart = self.startDate, let thisEnd = self.endDate,
            let otherStart = event.startDate, let otherEnd = event.endDate else {
          fatalError("One or both events do not have both start and end dates set.")
      }

      if thisStart == otherStart && thisEnd == otherEnd {
          return .same
      } else if thisEnd <= otherStart {
          return .before
      } else if thisStart >= otherEnd {
          return .after
      } else if thisStart < otherStart && thisEnd < otherEnd {
          return .overlapsAtStart
      } else if thisStart > otherStart && thisEnd > otherEnd {
          return .overlapsAtEnd
      } else if thisStart >= otherStart && thisEnd <= otherEnd {
          return .within
      } else if thisStart <= otherStart && thisEnd >= otherEnd{
          return .encompasses
      } else {
          fatalError("Unhandled case")
      }
  }
  func subtract(_ event: EKEvent) -> [EKEvent] {
      let comparisonResult = self.compare(to: event)
      switch comparisonResult {
      case .same:
          return []
      case .before, .after:
          return [self]
      case .overlapsAtStart:
          // self begins before the second event and ends within it
          let newEvent = EKEvent(eventStore: EKEventStore())
          newEvent.startDate = self.startDate
          newEvent.endDate = event.startDate
          return [newEvent]
      case .overlapsAtEnd:
          // self begins within the second event and ends after it
          let newEvent = EKEvent(eventStore: EKEventStore())
          newEvent.startDate = event.endDate
          newEvent.endDate = self.endDate
          return [newEvent]
      case .within:
          return []
      case .encompasses:
          let newEvent1 = EKEvent(eventStore: EKEventStore())
          newEvent1.startDate = self.startDate
          newEvent1.endDate = event.startDate
          let newEvent2 = EKEvent(eventStore: EKEventStore())
          newEvent2.startDate = event.endDate
          newEvent2.endDate = self.endDate
          return [newEvent1, newEvent2]
      }
  }
}

/// Subtracts an event from another event and returns the resulting events.
/// - Parameters:
///   - event: The event to subtract.
///   - otherEvent: The event to subtract from.
/// - Returns: An array of `EKEvent` objects representing the resulting events.
// func subtractEvents(_ event: EKEvent, from otherEvent: EKEvent) -> [EKEvent] {
//   let comparisonResult = event.compare(to: otherEvent)
//   switch comparisonResult {
//   case .same:
//     return []
//   case .before, .after:
//     return [event]
//   case .overlapsAtStart:
//     let newEvent = EKEvent(eventStore: EKEventStore())
//     newEvent.startDate = otherEvent.endDate
//     newEvent.endDate = event.endDate
//     return [newEvent]
//   case .overlapsAtEnd:
//     let newEvent = EKEvent(eventStore: EKEventStore())
//     newEvent.startDate = event.startDate
//     newEvent.endDate = otherEvent.startDate
//     return [newEvent]
//   case .within:
//     return []
//   case .encompasses:
//     let newEvent1 = EKEvent(eventStore: EKEventStore())
//     newEvent1.startDate = event.startDate
//     newEvent1.endDate = otherEvent.startDate
//     let newEvent2 = EKEvent(eventStore: EKEventStore())
//     newEvent2.startDate = otherEvent.endDate
//     newEvent2.endDate = event.endDate
//     return [newEvent1, newEvent2]
//   }
// }


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

func sortEventsByStartDate(_ events: [EKEvent]) -> [EKEvent] {
  return events.sorted { $0.startDate < $1.startDate }
}

// Merge overlapping events. We take a list of EKEvents and return a list of EKEvents.
// We sort them first by start date, then we iterate over the sorted list and merge
// any events that are overlapping. 
func mergeOverlappingEvents(_ events: [EKEvent]) -> [EKEvent] {
  // Handle the case where there are no events
  if events.count == 0 {
    return []
  }
  // Sort the events by start date
  let sortedEvents = sortEventsByStartDate(events)
  var mergedEvents = [EKEvent]()
  var currentEvent = sortedEvents[0]
  for event in sortedEvents[1...] {
    if currentEvent.endDate >= event.startDate {
      // The events overlap, so we need to merge them
      currentEvent.endDate = max(currentEvent.endDate, event.endDate)
    } else {
      // The events don't overlap, so we add the current event to the merged list
      mergedEvents.append(currentEvent)
      currentEvent = event
    }
  }
  // Append the last event
  mergedEvents.append(currentEvent)
  return mergedEvents
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

/// Parses a string representation of a date and returns a `Date` object.
/// - Parameter dateString: The string representation of the date.
/// - Returns: A `Date` object if the string can be parsed successfully, otherwise `nil`.
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

extension Date: ExpressibleByArgument {
  /// Initializes a new instance of `icaltoday` by parsing the given argument as a date.
  /// - Parameter argument: The string representation of the date to be parsed.
  /// - Returns: An initialized `icaltoday` instance if the argument can be successfully parsed as a date; otherwise, `nil`.
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

// A class that represents an hour and minute of the day. Can only
// represent times between 00:00 and 23:59. Is only initialized with
// valid times.
final class TimeOfDay {
  var hour: Int
  var minute: Int

  init?(hour: Int, minute: Int) {
    if hour < 0 || hour > 23 || minute < 0 || minute > 59 {
      return nil
    }
    self.hour = hour
    self.minute = minute
  }

  // Init from string
  init?(fromString string: String) {
    let components = string.components(separatedBy: ":")
    guard components.count == 2,
          let hour = Int(components[0]),
          let minute = Int(components[1]),
          let time = TimeOfDay(hour: hour, minute: minute) else {
      return nil
    }
    self.hour = time.hour
    self.minute = time.minute
  }

  // Returns a string representation of the time in the format "HH:MM"
  func toString() -> String {
    return String(format: "%02d:%02d", hour, minute)
  }

  // Convert to DateComponents
  func toDateComponents() -> DateComponents {
    var dateComponents = DateComponents()
    dateComponents.hour = hour
    dateComponents.minute = minute
    return dateComponents
  }

}

// Make TimeOfDay conform to ExpressibleByArgument
extension TimeOfDay: ExpressibleByArgument {
  /// Initializes a new instance of `TimeOfDay` by parsing the given argument as a time of day.
  /// - Parameter argument: The string representation of the time to be parsed.
  /// - Returns: An initialized `TimeOfDay` instance if the argument can be successfully parsed as a time of day; otherwise, `nil`.
  convenience init?(argument: String) {
    self.init(fromString: argument)
  }
}

// This function takes four arguments
// - startDate: The start date of the availability check
// - endDate: The end date of the availability check
// - startTime: The start time of the availability check for each day
// - endTime: The end time of the availability check for each day
// It returns a list of EKEvents that represent one event per day
// between startDate and endDate, with the start and end times set.
func getTimeBlockEvents(startDate: Date, endDate: Date, startTime: TimeOfDay, endTime: TimeOfDay) -> [EKEvent] {
  var availabilityEvents = [EKEvent]()
  let calendar = Calendar.current
  var currentDate = startDate
  while currentDate <= endDate {
    let event = EKEvent(eventStore: EKEventStore())
    event.startDate = calendar.date(bySettingHour: startTime.hour, minute: startTime.minute, second: 0, of: currentDate)!
    event.endDate = calendar.date(bySettingHour: endTime.hour, minute: endTime.minute, second: 0, of: currentDate)!
    availabilityEvents.append(event)
    currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
  }
  return availabilityEvents
}


// Function that returns true if authorizationStatus provides access
// to the calendar. Handles old version of macOS.
func hasAccessToCalendar(_ authorizationStatus: EKAuthorizationStatus) -> Bool {
#if OLD_EVKIT
  return authorizationStatus == .authorized
#else
  if #available(macOS 14, *) {
      return authorizationStatus == .authorized  || authorizationStatus == .fullAccess
  } else {
      return authorizationStatus == .authorized
  }
#endif
}

@main
struct icaltoday: ParsableCommand {
  static var configuration = CommandConfiguration(
    abstract: "A utility for performing querying calendars and events on Mac OS.",
    subcommands: [Calendars.self, Events.self, Authorize.self, Availability.self]
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
        let status = EKEventStore.authorizationStatus(for: .event)
        if !hasAccessToCalendar(status) {
          print("Access to the calendar is denied or restricted. Please grant access through System Preferences and try again.")
          Foundation.exit(1)
        }
        let eventStore = EKEventStore()
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
        let status = EKEventStore.authorizationStatus(for: .event)
        if !hasAccessToCalendar(status) {
          print("Access to the calendar is denied or restricted. Please grant access through System Preferences and try again.")
          Foundation.exit(1)
        }
        let eventStore = EKEventStore()
        let calendars = getMatchingCalendars(eventStore: eventStore, calendarNames: calendarNames)
        printEventsAsJSON(withEventStore: eventStore, withCalendars: calendars, withStart: startDate, withEnd: endDate)
      }
    }
  }
  struct Authorize: ParsableCommand {
    static var configuration = CommandConfiguration(
      abstract: "Requests access to the calendar."
    )

    func run() throws {
      let eventStore = EKEventStore()
      let semaphore = DispatchSemaphore(value: 0) // Create a semaphore

      print("Requesting access to the calendar...")

      eventStore.requestAccess(to: .event) { granted, error in
        defer { semaphore.signal() } // Signal the semaphore in the defer block to ensure it always gets called

        if let error = error {
          print("Error requesting access: \(error.localizedDescription)")
        } else if granted {
          print("Access to the calendar has been granted.")
        } else {
          print("Access to the calendar has been denied.")
        }
      }

      semaphore.wait() // Wait for the semaphore to be signaled before exiting
    }
  }
  // A subcommand to list availability between existing events
  struct Availability: ParsableCommand {
    static var configuration = CommandConfiguration(
      abstract: "Availability subcommand",
      subcommands: [List.self]
    )
    struct List: ParsableCommand {
      @Argument
      var startDate: Date
      @Argument
      var endDate: Date
      // StartTime must be in the format "HH:MM"
      @Argument
      var startTime: TimeOfDay
      // EndTime must be in the format "HH:MM"
      @Argument
      var endTime: TimeOfDay

      // Option for calendars to *exclude* from the availability check
      @Option(name: [.short, .customLong("exclude")])
      var excludeCalendarNames: [String] = []
      // Option for calendars to *include* in the availability check
      @Option(name: [.short, .customLong("include")])
      var includeCalendarNames: [String] = []

      static var configuration = CommandConfiguration(
        abstract: "List subcommand"
      )
      mutating func run() throws {
        let status = EKEventStore.authorizationStatus(for: .event)

        if !hasAccessToCalendar(status) {
          print("Access to the calendar is denied or restricted. Please grant access through System Preferences and try again.")
          Foundation.exit(1)
        } 
        // For now, just log the arguments
        print("Start date: \(startDate)")
        print("End date: \(endDate)")
        print("Start time: \(startTime.toString())")
        print("End time: \(endTime.toString())")
        print("Exclude calendars: \(excludeCalendarNames)")
        print("Include calendars: \(includeCalendarNames)")
      }
    }
  }
}

