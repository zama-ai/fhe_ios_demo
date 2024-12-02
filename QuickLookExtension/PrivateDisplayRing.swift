// Copyright © 2024 Zama. All rights reserved.

import SwiftUI

#Preview {
    Text("This data is private and wide enough")
        .privateDisplayRing()

    Text("This one shorter")
        .privateDisplayRing()
}

extension View {
    func privateDisplayRing() -> some View {
        self.modifier(PrivateDisplayRing())
    }
}

private struct PrivateDisplayRing: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .overlay {
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(.tint, lineWidth: 2)
            }
            .padding(.bottom, 16)
            .overlay(alignment: .bottom) {
                let icon = Image(systemName:"lock.fill")
                ViewThatFits {
                    Text("\(icon) Privately Displayed, app cannot see this.")
                    Text("\(icon) Private Display")
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .imageScale(.small)
                }
                .foregroundStyle(.tint)
                .customFont(.caption2).bold()
            }
            .padding(.bottom, 8)
            .buttonStyle(.plain)
            .tint(.black)
    }
}
