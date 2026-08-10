//
//  TimePickerComponents.swift
//  TimePicker
//
//  Created by Quien on 2026-06-08.
//

import Foundation

/// The set of time units a ``TimePicker`` shows and a ``DurationFormatter`` emits.
///
/// Use a preset such as ``hoursMinutesSeconds`` or ``minutesSeconds``, or compose
/// your own (e.g. `[.minutes, .seconds]`). Units always render and format in
/// descending order — hours, then minutes, then seconds — regardless of insertion order.
public struct TimePickerComponents: OptionSet, Sendable {
  public let rawValue: Int

  public init(rawValue: Int) {
    self.rawValue = rawValue
  }

  public static let hours = TimePickerComponents(rawValue: 1 << 0)
  public static let minutes = TimePickerComponents(rawValue: 1 << 1)
  public static let seconds = TimePickerComponents(rawValue: 1 << 2)

  /// Hours, minutes, and seconds (the default).
  public static let hoursMinutesSeconds: TimePickerComponents = [.hours, .minutes, .seconds]
  /// Minutes and seconds only (e.g. a stopwatch-style picker).
  public static let minutesSeconds: TimePickerComponents = [.minutes, .seconds]
  /// Hours and minutes only.
  public static let hoursMinutes: TimePickerComponents = [.hours, .minutes]
}

extension TimePickerComponents {
  /// The configured units in descending order (hours → minutes → seconds).
  var orderedUnits: [DurationUnit] {
    var units: [DurationUnit] = []
    if contains(.hours) { units.append(.hours) }
    if contains(.minutes) { units.append(.minutes) }
    if contains(.seconds) { units.append(.seconds) }
    return units
  }
}
