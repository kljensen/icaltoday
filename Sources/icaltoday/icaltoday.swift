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
      let otherStart = event.startDate, let otherEnd = event.endDate
    else {
      fatalError("One or both events do not have both start and end dates set.")
    }

    if thisStart == otherStart && thisEnd == otherEnd {
      return .same
    } else if thisEnd <= otherStart {
      return .before
    } else if thisStart >= otherEnd {
      return .after
    } else if thisStart <= otherStart && thisEnd < otherEnd {
      return .overlapsAtStart
    } else if thisStart > otherStart && thisEnd >= otherEnd {
      return .overlapsAtEnd
    } else if thisStart <= otherStart && thisEnd >= otherEnd {
      return .encompasses
    } else if thisStart >= otherStart && thisEnd <= otherEnd {
      return .within
    } else {
      fatalError("Unhandled case")
    }
  }
  func subtract(_ event: EKEvent) -> [EKEvent] {
    if(event.startDate == event.endDate){
      return [self]
    }
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
      // The first encompases the second. 
      var events = [EKEvent]();
      if (self.startDate != event.startDate) {
        let newEvent1 = EKEvent(eventStore: EKEventStore())
        newEvent1.startDate = self.startDate
        newEvent1.endDate = event.startDate
        events.append(newEvent1)
      }
      if (self.endDate != event.endDate) {
        let newEvent2 = EKEvent(eventStore: EKEventStore())
        newEvent2.startDate = event.endDate
        newEvent2.endDate = self.endDate
        events.append(newEvent2)
      }
      return events
    }
  }
  // Overload subtract to handle multiple events
  func subtract(_ events: [EKEvent]) -> [EKEvent] {
    var remainingEvents = [self]
    for event in events {
      var newRemainingEvents = [EKEvent]()
      for remainingEvent in remainingEvents {
        let subtractedEvents = remainingEvent.subtract(event)
        newRemainingEvents.append(contentsOf: subtractedEvents)
      }
      remainingEvents = newRemainingEvents
    }
    return remainingEvents
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
  var startDate: Date
  var endDate: Date
  var uid: String
  var uidAsBase64: String
  var isToday: Bool
  static func fromEKEvent(event: EKEvent) -> SimpleEvent {
    return SimpleEvent(
      name: event.title, attendeeEmails: event.attendees?.compactMap { $0.email } ?? [],
      startDate: event.startDate,
      endDate: event.endDate,
      uid: event.calendarItemExternalIdentifier,
      uidAsBase64: event.calendarItemExternalIdentifierAsBase64, isToday: event.isToday()
    )
  }
}

extension JSONEncoder {
    static let localTimeEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        dateFormatter.timeZone = TimeZone.current
        encoder.dateEncodingStrategy = .formatted(dateFormatter)
        return encoder
    }()
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

func encodeToJSONString(events: [EKEvent]) -> String? {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    
    let dateFormatter = ISO8601DateFormatter()
    dateFormatter.timeZone = TimeZone.current
    encoder.dateEncodingStrategy = .custom({ date, encoder in
        var container = encoder.singleValueContainer()
        let dateString = dateFormatter.string(from: date)
        try container.encode(dateString)
    })
    let simpleEvents = events.map { SimpleEvent.fromEKEvent(event: $0) } 
    do {
        let data = try encoder.encode(simpleEvents)
        return String(data: data, encoding: .utf8)
    } catch {
        print("Error encoding meetings to JSON: \(error)")
        return nil
    }
}

func printEventsAsJSON(
  withEventStore eventStore: EKEventStore, withCalendars calendars: [EKCalendar],
  withStart startDate: Date, withEnd endDate: Date
) {
  if calendars == [] {
    print("{}")
    return
  }
  let predicate = eventStore.predicateForEvents(
    withStart: startDate, end: endDate, calendars: calendars
  )
  let events = eventStore.events(matching: predicate)

  // Print the events as JSON
  if let jsonString = encodeToJSONString(events: events) {
    print(jsonString)
  }
}


enum ValidDay {
  case today
  case tomorrow
  case yesterday
}

struct NaturalDate {
  var day: ValidDay
  var delta: Int?

  init(day: ValidDay, delta: Int?) {
    self.day = day
    self.delta = delta
  }
  init(day: ValidDay){
    self.day = day
    self.delta = nil
  }

  init?(fromString string: String) {
    let lowerString = string.lowercased()
    var suffix: String = ""
    if lowerString.hasPrefix("today") {
      day = .today
      suffix = String(lowerString.dropFirst("today".count))
    } else if lowerString.hasPrefix("tomorrow") {
      day = .tomorrow
      suffix = String(lowerString.dropFirst("tomorrow".count))
    } else if lowerString.hasPrefix("yesterday") {
      day = .yesterday
      suffix = String(lowerString.dropFirst("yesterday".count))
    } else {
      return nil
    }
    // No suffix provided
    guard !suffix.isEmpty else {
      return
    }
    // Test that suffix starts with either a "-" or a "+"
    guard let firstChar = suffix.first, firstChar == "-" || firstChar == "+" else {
      return nil
    }
    delta = Int(suffix)
  }
}

// Equitable
extension NaturalDate: Equatable {
  static func == (lhs: NaturalDate, rhs: NaturalDate) -> Bool {
    return lhs.day == rhs.day && lhs.delta == rhs.delta
  }
}

// Implement the ExpressibleByArgument protocol for NaturalDate



// A function that parses natural language dates and returns a `Date` object.
// This takes strings that start with either "today", "tomorrow", or "yesterday"
// and potentially include a suffix like "+10" or "-4". Returns a Result type.


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
      let time = TimeOfDay(hour: hour, minute: minute)
    else {
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
func getTimeBlockEvents(startDate: Date, endDate: Date, startTime: TimeOfDay, endTime: TimeOfDay)
  -> [EKEvent]
{
  var availabilityEvents = [EKEvent]()
  let calendar = Calendar.current
  var currentDate = startDate
  while currentDate <= endDate {
    let event = EKEvent(eventStore: EKEventStore())
    event.startDate = calendar.date(
      bySettingHour: startTime.hour, minute: startTime.minute, second: 0, of: currentDate)!
    event.endDate = calendar.date(
      bySettingHour: endTime.hour, minute: endTime.minute, second: 0, of: currentDate)!
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
      return authorizationStatus == .authorized || authorizationStatus == .fullAccess
    } else {
      return authorizationStatus == .authorized
    }
  #endif
}

func listAvailability(
  startDate: Date, endDate: Date, startTime: TimeOfDay, endTime: TimeOfDay,
  excludeCalendarNames: [String], includeCalendarNames: [String],
  excludeAllDayEvents: Bool
) {

  // Get the start by adding startDate to startTime
  let startComponents = startTime.toDateComponents()
  let endComponents = endTime.toDateComponents()
  let startDateTime = Calendar.current.date(byAdding: startComponents, to: startDate)!
  let endDateTime = Calendar.current.date(byAdding: endComponents, to: startDate)!

  let eventStore = EKEventStore()
  let calendars = getMatchingCalendars(eventStore: eventStore, calendarNames: includeCalendarNames)
  // For some reason this is not picking up the events I thought it should 
  // be. This is where I left off.
  let predicate = eventStore.predicateForEvents(
    withStart: startDateTime,
    end: endDateTime,
    calendars: calendars
  )
  let events = eventStore.events(matching: predicate)
  let possibleWindows = getTimeBlockEvents(startDate: startDate, endDate: endDate, startTime: startTime, endTime: endTime)
  let filteredEvents = events.filter { event in
    !excludeCalendarNames.contains(event.calendar.title)
  }.filter { event in
    !excludeAllDayEvents || !event.isAllDay
  }
  let mergedEvents = mergeOverlappingEvents(filteredEvents)
  let availability = mergedEvents.reduce(possibleWindows) { remainingWindows, event in
    return remainingWindows.flatMap { $0.subtract(event) }
  }
  // Set the name of each event to "free"
  availability.forEach { event in
    event.title = "free"
  }
  // Print the events as JSON
  if let jsonString = encodeToJSONString(events: availability) {
    print(jsonString)
  }
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
          print(
            "Access to the calendar is denied or restricted. Please grant access through System Preferences and try again."
          )
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
          print(
            "Access to the calendar is denied or restricted. Please grant access through System Preferences and try again."
          )
          Foundation.exit(1)
        }
        let eventStore = EKEventStore()
        let calendars = getMatchingCalendars(eventStore: eventStore, calendarNames: calendarNames)
        printEventsAsJSON(
          withEventStore: eventStore, withCalendars: calendars, withStart: startDate,
          withEnd: endDate)
      }
    }
  }
  struct Authorize: ParsableCommand {
    static var configuration = CommandConfiguration(
      abstract: "Requests access to the calendar."
    )

    func run() throws {
      let eventStore = EKEventStore()
      let semaphore = DispatchSemaphore(value: 0)  // Create a semaphore

      print("Requesting access to the calendar...")

      eventStore.requestAccess(to: .event) { granted, error in
        defer { semaphore.signal() }  // Signal the semaphore in the defer block to ensure it always gets called

        if let error = error {
          print("Error requesting access: \(error.localizedDescription)")
        } else if granted {
          print("Access to the calendar has been granted.")
        } else {
          print("Access to the calendar has been denied.")
        }
      }

      semaphore.wait()  // Wait for the semaphore to be signaled before exiting
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

      // Boolean option to exclude all-day events
      @Flag(name: [.customLong("exclude-all-day")])
      var excludeAllDayEvents: Bool = false

      static var configuration = CommandConfiguration(
        abstract: "List subcommand"
      )
      mutating func run() throws {
        let status = EKEventStore.authorizationStatus(for: .event)

        if !hasAccessToCalendar(status) {
          print(
            "Access to the calendar is denied or restricted. Please grant access through System Preferences and try again."
          )
          Foundation.exit(1)
        }
        // Ensure start date is before end date
        if startDate > endDate {
          print("Start date must be before end date.")
          Foundation.exit(1)
        }
        // Ensure start time is before end time
        if startTime.hour > endTime.hour ||
          (startTime.hour == endTime.hour && startTime.minute >= endTime.minute)
        {
          print("Start time must be before end time.")
          Foundation.exit(1)
        }

        // For now, just log the arguments
        listAvailability(
          startDate: startDate,
          endDate: endDate,
          startTime: startTime,
          endTime: endTime,
          excludeCalendarNames: excludeCalendarNames,
          includeCalendarNames: includeCalendarNames,
          excludeAllDayEvents: excludeAllDayEvents
        )
      }
    }
  }
}
