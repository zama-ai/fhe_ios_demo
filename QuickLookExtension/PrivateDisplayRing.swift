// Copyright © 2024 Zama. All rights reserved.

import SwiftUI

#Preview {
    Text("This data is private and wide enough")
        .privateDisplayRing()

    Text("This one also")
        .border(.blue)
        .privateDisplayRing()
        .border(.red)

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
                Link(destination: URL(string: "https://zama.ai")!) {
                    let eye = Image(systemName:"eye.slash")
                    let info = Image(systemName:"info.circle")
                    ViewThatFits {
                        Text("\(eye) Privately Displayed, app cannot see this. \(info)")
                        Text("Private Display \(info)")
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .imageScale(.small)
                    }
                }
                .foregroundStyle(.tint)
                .font(.caption2).bold()
            }
            .padding(.bottom, 8)
            .buttonStyle(.plain)
            .tint(.orange)
    }
}
