//
//  DurationWheelPicker.swift
//  TimePicker
//
//  Created by Quien on 2026-01-05.
//

import SwiftUI

struct DurationWheelPicker: View {
  @Binding var duration: DurationValue
  let components: TimePickerComponents
  let maximumHours: Int

  var body: some View {
    HStack {
      if components.contains(.hours) {
        DurationWheelColumn(
          title: "Hour",
          value: $duration.hours,
          range: 0...maximumHours)
      }

      if components.contains(.minutes) {
        DurationWheelColumn(
          title: "Min",
          value: $duration.minutes,
          range: 0...59)
      }

      if components.contains(.seconds) {
        DurationWheelColumn(
          title: "Sec",
          value: $duration.seconds,
          range: 0...59)
      }
    }  // HStack
  }
}

#Preview("hr : min : sec") {
  DurationWheelPicker(
    duration: .constant(DurationValue()),
    components: .hoursMinutesSeconds,
    maximumHours: 23)
}

#Preview("hr : min") {
  DurationWheelPicker(
    duration: .constant(DurationValue()),
    components: .hoursMinutes,
    maximumHours: 23)
}

#Preview("min : sec") {
  DurationWheelPicker(
    duration: .constant(DurationValue()),
    components: .minutesSeconds,
    maximumHours: 23)
}
