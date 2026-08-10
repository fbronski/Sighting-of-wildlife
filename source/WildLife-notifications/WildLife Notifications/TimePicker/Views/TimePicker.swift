//
//  TimePicker.swift
//  TimePicker
//
//  Created by Quien on 2026-01-04.
//

import SwiftUI

/// A control that presents a wheel-based duration picker in a sheet and binds the result to
/// a `TimeInterval?`.
///
/// Configure which units appear with `components` (e.g. ``TimePickerComponents/minutesSeconds``)
/// and the hours range with `maximumHours`. Theme it with
/// ``SwiftUICore/View/timePickerStyle(_:)``. To render the same value elsewhere, use
/// ``DurationFormatter``.l
@MainActor
public struct TimePicker<Label: View>: View {
  // MARK: - Environment
  @Environment(\.timePickerStyle) private var style

  // MARK: - State
  @State private var draftDuration: DurationValue
  @State private var isPresentingPickerView = false
  @State private var isCanceled = false


  // MARK: - Properties
  private let label: Label
  private let title: LocalizedStringKey
  private let components: TimePickerComponents
  private let maximumHours: Int
  @Binding private var value: TimeInterval?

  // MARK: - Init
  public init(
    _ title: LocalizedStringKey = "Select Time",
    components: TimePickerComponents = .hoursMinutesSeconds,
    maximumHours: Int = 23,
    selection value: Binding<TimeInterval?>
  ) where Label == Text {
    self.title = title
    self.components = components
    self.maximumHours = maximumHours
    self.label = Text(title)
    self._value = value
    self._draftDuration = State(initialValue: DurationValue(value.wrappedValue))
  }

  // MARK: - Custom label init
  public init(
    _ title: LocalizedStringKey = "Select Time",
    components: TimePickerComponents = .hoursMinutesSeconds,
    maximumHours: Int = 23,
    selection value: Binding<TimeInterval?>,
    @ViewBuilder label: () -> Label
  ) {
    self.title = title
    self.components = components
    self.maximumHours = maximumHours
    self.label = label()
    self._value = value
    self._draftDuration = State(initialValue: DurationValue(value.wrappedValue))
  }

  // MARK: - Computed
  private var formatter: DurationFormatter {
    DurationFormatter(components: components, showsPlaceholderWhenZero: true)
  }

  // MARK: - Body
  public var body: some View {
    HStack {
      label

      Spacer()

      Button {
        draftDuration = DurationValue(value)
        isPresentingPickerView = true
      } label: {
        Text(formatter.string(from: value))
          .fontWeight(style.fontWeight)
          .foregroundStyle(style.accentColor)
      }
      .buttonStyle(.bordered)
    }  // HStack
    .sheet(isPresented: $isPresentingPickerView) {
      TimePickerSheet(
        draftDuration: $draftDuration,
        value: $value,
        isPresenting: $isPresentingPickerView,
        isCanceled: $isCanceled,
        title: title,
        components: components,
        maximumHours: maximumHours
      )
      .timePickerStyle(style)
    }
  }
}

#Preview {
  NavigationStack {
    Form {
      TimePicker("Finish Time", selection: .constant(TimeInterval(3 * 3600 + 20 * 60 + 44)))
      TimePicker("Lap Time", components: .minutesSeconds, selection: .constant(nil)) {
        Text("Lap Time")
      }
    }
    .navigationTitle("TimePicker Preview")
    .timePickerStyle(accentColor: .orange)
  }
}
