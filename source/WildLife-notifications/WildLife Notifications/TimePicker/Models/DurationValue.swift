//
//  DurationValue.swift
//  TimePicker
//
//  Created by Quien on 2026-01-04.
//

import Foundation

/// Internal hours/minutes/seconds storage for the picker.
///
/// Display and parsing live in the public ``DurationFormatter``; this type only holds the
/// wheel-bound components and converts to and from `TimeInterval`. Minutes and seconds are
/// clamped to `0...59`; hours are unbounded.
struct DurationValue: Equatable {
  var hours: Int
  var minutes: Int
  var seconds: Int

  init(hours: Int = 0, minutes: Int = 0, seconds: Int = 0) {
    self.hours = max(0, hours)
    self.minutes = min(max(0, minutes), 59)
    self.seconds = min(max(0, seconds), 59)
  }

  init(_ timeInterval: TimeInterval?) {
    let total = Int(max(0, timeInterval ?? 0))
    self.hours = total / 3600
    self.minutes = (total % 3600) / 60
    self.seconds = total % 60
  }

  var timeInterval: TimeInterval {
    TimeInterval(hours * 3600 + minutes * 60 + seconds)
  }

  var isEmpty: Bool {
    hours == 0 && minutes == 0 && seconds == 0
  }

    var timeString: String {
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}
