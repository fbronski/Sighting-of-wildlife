//
//  TimePickerStyle.swift
//  TimePicker
//
//  Created by Quien on 2026-06-08.
//

import SwiftUI

/// Appearance for ``TimePicker`` and its sheet.
///
/// Apply a style to a view subtree with ``SwiftUICore/View/timePickerStyle(_:)`` to theme
/// every picker on a screen, or override individual properties with
/// ``SwiftUICore/View/timePickerStyle(accentColor:fontWeight:cornerRadius:wheelHeight:detents:)``.
public struct TimePickerStyle: Sendable {
  /// Tint for the value label, confirm button, and sheet accents.
  public var accentColor: Color
  /// Weight of the value label.
  public var fontWeight: Font.Weight
  /// Corner radius of the sheet's value display.
  public var cornerRadius: CGFloat
  /// Height of each wheel column.
  public var wheelHeight: CGFloat
  /// Presentation detents for the picker sheet.
  public var detents: Set<PresentationDetent>

  public init(
    accentColor: Color = .primary,
    fontWeight: Font.Weight = .regular,
    cornerRadius: CGFloat = 20,
    wheelHeight: CGFloat = 120,
    detents: Set<PresentationDetent> = [.medium]
  ) {
    self.accentColor = accentColor
    self.fontWeight = fontWeight
    self.cornerRadius = cornerRadius
    self.wheelHeight = wheelHeight
    self.detents = detents
  }
}

extension EnvironmentValues {
  /// The style applied to ``TimePicker`` instances in this environment.
  @Entry public var timePickerStyle = TimePickerStyle()
}

extension View {
  /// Sets the style for ``TimePicker`` instances within this view.
  public func timePickerStyle(_ style: TimePickerStyle) -> some View {
    environment(\.timePickerStyle, style)
  }

  /// Overrides individual ``TimePickerStyle`` properties, leaving the rest inherited from
  /// the environment. Pass `nil` (the default) to leave a property unchanged.
  public func timePickerStyle(
    accentColor: Color? = nil,
    fontWeight: Font.Weight? = nil,
    cornerRadius: CGFloat? = nil,
    wheelHeight: CGFloat? = nil,
    detents: Set<PresentationDetent>? = nil
  ) -> some View {
    transformEnvironment(\.timePickerStyle) { style in
      if let accentColor { style.accentColor = accentColor }
      if let fontWeight { style.fontWeight = fontWeight }
      if let cornerRadius { style.cornerRadius = cornerRadius }
      if let wheelHeight { style.wheelHeight = wheelHeight }
      if let detents { style.detents = detents }
    }
  }
}
