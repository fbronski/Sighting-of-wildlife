//
//  DurationFormatter.swift
//  TimePicker
//
//  Created by Quien on 2026-06-08.
//

import Foundation

/// Converts between a `TimeInterval` and its grouped string form (e.g. `"03 : 20 : 44"`).
///
/// This is the public counterpart to ``TimePicker``'s internal model: use it to render
/// durations consistently elsewhere in an app (summary labels, list rows) or to parse
/// user-entered strings back into a `TimeInterval`, without depending on the picker's
/// private storage type.
///
/// The largest configured unit absorbs any overflow, so a `.minutesSeconds` formatter
/// renders 3700 seconds as `"61 : 40"` rather than dropping the extra hour.
public struct DurationFormatter: Sendable {
  /// The units to include, in descending order.
  public var components: TimePickerComponents
  /// When `true`, a zero/`nil` interval renders as a placeholder (e.g. `"-- : -- : --"`)
  /// instead of zeros (`"00 : 00 : 00"`).
  public var showsPlaceholderWhenZero: Bool

  public init(
    components: TimePickerComponents = .hoursMinutesSeconds,
    showsPlaceholderWhenZero: Bool = false
  ) {
    self.components = components
    self.showsPlaceholderWhenZero = showsPlaceholderWhenZero
  }

  private static let separator = " : "
  private static let placeholderUnit = "--"

  /// Renders an interval, e.g. `"03 : 20 : 44"`. A `nil` or non-positive interval renders
  /// as zeros, or as a placeholder when ``showsPlaceholderWhenZero`` is set.
  public func string(from interval: TimeInterval?) -> String {
    let units = components.orderedUnits
    guard !units.isEmpty else { return "" }

    let total = Int(max(0, interval ?? 0))
    if total == 0 && showsPlaceholderWhenZero {
      return
        units
        .map { _ in Self.placeholderUnit }
        .joined(separator: Self.separator)
    }

    var remaining = total
    var parts: [String] = []
    for unit in units {
      parts.append(String(format: "%02d", remaining / unit.secondsPerUnit))
      remaining %= unit.secondsPerUnit
    }
    return parts.joined(separator: Self.separator)
  }

  /// Parses a grouped string (e.g. `"03 : 20 : 44"`) back into a `TimeInterval`.
  ///
  /// The number of groups must match ``components``; whitespace around separators is
  /// ignored. Returns `nil` if the string is malformed.
  public func interval(from string: String) -> TimeInterval? {
    let units = components.orderedUnits
    let parts =
      string
      .split(separator: ":")
      .map { $0.trimmingCharacters(in: .whitespaces) }
    guard parts.count == units.count else { return nil }

    var total = 0
    for (part, unit) in zip(parts, units) {
      guard let value = Int(part), value >= 0 else { return nil }
      total += value * unit.secondsPerUnit
    }
    return TimeInterval(total)
  }
}
