// Copyright © 2025 Zama. All rights reserved.

import SwiftUI

struct SecurelyDisplayedModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.bottom, 15)
            .overlay {
                Rectangle()
                    .stroke(lineWidth: 1/UIScreen.main.scale)
            }
            .overlay(alignment: .bottomLeading) {
                let icon = Image(systemName: "lock.fill")
                ViewThatFits {
                    Text("\(icon) Data is securely decrypted and displayed")
                    Text("\(icon) Data securely displayed")
                    Text("\(icon) Securely displayed")
                    Text("\(icon) Secure")
                }
                .frame(maxWidth: .infinity)
                .foregroundStyle(.secondary)
                .customFont(.caption)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .fontWeight(.regular)
                .padding(1)
            }
    }
}

extension View {
    func securelyDisplayed() -> some View {
        self.modifier(SecurelyDisplayedModifier())
    }
}
