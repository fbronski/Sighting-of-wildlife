//
//  DurationUnit.swift
//  TimePicker
//
//  Created by Quien on 2026-06-08.
//

/// A single time unit, carrying its conversion factor to seconds.
enum DurationUnit: CaseIterable {
  case hours
  case minutes
  case seconds

  var secondsPerUnit: Int {
    switch self {
    case .hours: 3600
    case .minutes: 60
    case .seconds: 1
    }
  }
}
