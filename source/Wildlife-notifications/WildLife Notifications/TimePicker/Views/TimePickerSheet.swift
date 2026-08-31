//
//  TimePickerSheet.swift
//  TimePicker
//
//  Created by Quien on 2026-04-15.
//

import SwiftUI

struct TimePickerSheet: View {
  // MARK: - Environment
  @Environment(\.timePickerStyle) private var style
  @AppStorage("languageIndex") private var languageIndex = 0

  // MARK: - Properties
  @Binding var draftDuration: DurationValue
  @Binding var value: TimeInterval?
  @Binding var isPresenting: Bool
  @Binding var isCanceled: Bool
  let title: LocalizedStringKey
  let components: TimePickerComponents
  let maximumHours: Int

  // MARK: - Computed
  private var formatter: DurationFormatter {
    DurationFormatter(components: components)
  }

  // MARK: - Body
  var body: some View {
    NavigationStack {
      VStack {
        Text(formatter.string(from: draftDuration.timeInterval))
          .font(.title)
          .fontWeight(.bold)
          .frame(maxWidth: .infinity)
          .padding(.vertical)
          .foregroundStyle(style.accentColor)
          .background(style.accentColor.opacity(0.1))
          .clipShape(.rect(cornerRadius: style.cornerRadius))
          .overlay(
            RoundedRectangle(cornerRadius: style.cornerRadius)
              .stroke(style.accentColor.opacity(0.3), lineWidth: 1)
          )
          .padding()

        DurationWheelPicker(
          duration: $draftDuration,
          components: components,
          maximumHours: maximumHours
        )

        Spacer()

        Divider()

        Button {
          draftDuration = DurationValue()
        } label: {
          Text("Clear")
            .foregroundStyle(.red)
        }
        .padding(.vertical, 8)
      }  // VStack
      .navigationTitle(title)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(appText(.cancel, languageIndex: languageIndex), role: .cancel) {
            isPresenting = false
            isCanceled = true
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(appText(.continueAction, languageIndex: languageIndex)) {
            value = draftDuration.isEmpty ? nil : draftDuration.timeInterval
            isPresenting = false
            isCanceled = false
          }
          .foregroundStyle(style.accentColor)
        }
      }  // toolbar
      .presentationDetents(style.detents)
    }  // NavigationStack
  }
}

#Preview {
  @Previewable @State var duration = DurationValue(3 * 3600 + 20 * 60 + 44)
  @Previewable @State var value: TimeInterval?
  @Previewable @State var isPresenting = true
  @Previewable @State var isCanceled = true
  @Previewable @State var showAlert = false

  TimePickerSheet(
    draftDuration: $duration,
    value: $value,
    isPresenting: $isPresenting,
    isCanceled: $isCanceled,
    title: "Finish Time",
    components: .hoursMinutesSeconds,
    maximumHours: 23
  )
  .timePickerStyle(accentColor: .orange)
}
