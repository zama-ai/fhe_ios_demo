// Copyright © 2025 Zama. All rights reserved.

import SwiftUI

struct SecurelyDisplayedModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.bottom, 14)
            .overlay(alignment: .bottomLeading) {
                let icon = Image(systemName: "lock.fill")
                ViewThatFits {
                    Text("\(icon) Data securely decrypted and displayed")
                    Text("\(icon) Data securely displayed")
                    Text("\(icon) Securely displayed")
                    Text("\(icon) Secure")
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .foregroundStyle(.secondary)
                .customFont(.caption2)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .fontWeight(.regular)
            }
    }
}

extension View {
    func securelyDisplayed() -> some View {
        self.modifier(SecurelyDisplayedModifier())
    }
}
