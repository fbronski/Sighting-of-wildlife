//
//  DurationWheelColumn.swift
//  TimePicker
//
//  Created by Quien on 2026-01-04.
//

import SwiftUI

struct DurationWheelColumn: View {
  @Environment(\.timePickerStyle) private var style
  let title: LocalizedStringKey
  @Binding var value: Int
  let range: ClosedRange<Int>

  var body: some View {
    VStack(alignment: .center, spacing: 0) {
      Picker(selection: $value) {
        ForEach(range, id: \.self) { value in
          Text("\(value)")
            .monospacedDigit()
            .tag(value)
        }
      } label: {
        Text(title)
      }
      .pickerStyle(.wheel)
      .frame(height: style.wheelHeight)
      .clipped()

      Text(title)
    }  // VStack
    .frame(minWidth: 60)
  }
}

#Preview {
  HStack {
    DurationWheelColumn(title: "Hour", value: .constant(3), range: 0...23)
    DurationWheelColumn(title: "Min", value: .constant(20), range: 0...59)
  }
}
