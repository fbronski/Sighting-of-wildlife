//
//  SettingTextField.swift
//  Setting
//
//  Created by A. Zheng (github.com/aheze) on 2/24/23.
//  Copyright © 2023 A. Zheng. All rights reserved.
//

import SwiftUI

/**
 A text field.
 */
public struct SettingTextField: View, @MainActor Setting {
    public var id: AnyHashable?
    public var placeholder: String
    public var secure: Bool
    @Binding public var text: String
    public var verticalPadding = CGFloat(14)
    public var horizontalPadding: CGFloat? = nil

    public init(
        id: AnyHashable? = nil,
        placeholder: String,
        secure: Bool,
        text: Binding<String>,
        verticalPadding: CGFloat = CGFloat(14),
        horizontalPadding: CGFloat? = nil
    ) {
        self.id = id
        self.placeholder = placeholder
        self.secure = secure
        self._text = text
        self.verticalPadding = verticalPadding
        self.horizontalPadding = horizontalPadding
    }

    public var body: some View {
        SettingTextFieldView(
            placeholder: placeholder,
            secure: secure,
            text: $text,
            verticalPadding: verticalPadding,
            horizontalPadding: horizontalPadding
        )
    }
}

struct SettingTextFieldView: View {
    @Environment(\.edgePadding) var edgePadding
    
    let placeholder: String
    let secure: Bool
    @Binding var text: String
    var verticalPadding = CGFloat(14)
    var horizontalPadding: CGFloat? = nil

    var body: some View {
        if secure {
            SecureField(placeholder, text: $text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, verticalPadding)
                .padding(.horizontal, horizontalPadding ?? edgePadding)
                .accessibilityElement(children: .combine)
        }else{
            TextField(placeholder, text: $text)
            
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, verticalPadding)
                .padding(.horizontal, horizontalPadding ?? edgePadding)
                .accessibilityElement(children: .combine)
        }
    }
}
