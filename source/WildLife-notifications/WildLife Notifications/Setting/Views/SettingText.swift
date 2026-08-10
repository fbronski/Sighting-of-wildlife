//
//  SettingText.swift
//  Setting
//
//  Created by A. Zheng (github.com/aheze) on 2/21/23.
//  Copyright © 2023 A. Zheng. All rights reserved.
//

import SwiftUI

/**
 A simple text view.
 */
public struct SettingText: View, @MainActor Setting {
    public var id: AnyHashable?
    public var title: String
    public var bold: Bool = false
    public var foregroundColor: Color?
    public var horizontalSpacing = CGFloat(12)
    public var verticalPadding = CGFloat(14)
    public var horizontalPadding: CGFloat? = nil

    public init(
        id: AnyHashable? = nil,
        title: String,
        bold: Bool = false,
        foregroundColor: Color? = nil,
        horizontalSpacing: CGFloat = CGFloat(12),
        verticalPadding: CGFloat = CGFloat(14),
        horizontalPadding: CGFloat? = nil
    ) {
        self.id = id
        self.title = title
        self.bold = bold
        self.foregroundColor = foregroundColor
        self.horizontalSpacing = horizontalSpacing
        self.verticalPadding = verticalPadding
        self.horizontalPadding = horizontalPadding
    }

    public var body: some View {
        SettingTextView(
            title: title,
            bold: bold,
            foregroundColor: foregroundColor,
            horizontalSpacing: horizontalSpacing,
            verticalPadding: verticalPadding,
            horizontalPadding: horizontalPadding
        )
    }
}

struct SettingTextView: View {
    @Environment(\.edgePadding) var edgePadding
    @Environment(\.settingPrimaryColor) var settingPrimaryColor

    let title: String
    let bold: Bool
    var foregroundColor: Color?
    var horizontalSpacing = CGFloat(12)
    var verticalPadding = CGFloat(14)
    var horizontalPadding: CGFloat? = nil

    var body: some View {
        Text(title)
            .foregroundColor(foregroundColor ?? settingPrimaryColor)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .bold(bold)
            .padding(.vertical, verticalPadding)
            .padding(.horizontal, horizontalPadding ?? edgePadding)
            
        
       
    }
}
