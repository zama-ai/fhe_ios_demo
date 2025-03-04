// Copyright © 2025 Zama. All rights reserved.

import SwiftUI

#Preview {
    VStack {
        Button("Foo") {}.buttonStyle(.custom)
        Button("Foo") {}.buttonStyle(.custom).disabled(true)

        Button("Foo") {}.buttonStyle(.blackHighlight())
        Button("Foo") {}.buttonStyle(.blackHighlight()).disabled(true)

        AsyncButton(action: {}) {
            Label("Import Health Information", systemImage: "heart.text.clipboard")
        }.buttonStyle(.custom)
        
        Spacer()
    }
    .padding()
    .background(Color.zamaYellowLight)
}

struct CustomButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration config: Configuration) -> some View {
        config.label
            .opacity(isEnabled ? 1 : 0.5)
            .padding(12)
            .frame(maxWidth: .infinity)
            .fontWeight(.bold)
            .background(.zamaYellow)
            .border(config.isPressed ? .black : .clear, width: 1)
            .animation(.none, value: config.isPressed)
    }
}

struct BlackHighlightButtonStyle: ButtonStyle {
    var disabled: Bool
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration config: Configuration) -> some View {
        if disabled {
            config.label
        } else {
            config.label
                .opacity(isEnabled ? 1 : 0.5)
                .border(.black, width: config.isPressed ? 1 : 0)
                .animation(.none, value: config.isPressed)
        }
    }
}


extension ButtonStyle where Self == CustomButtonStyle {
    static var custom: CustomButtonStyle {
        CustomButtonStyle()
    }
    
    static func blackHighlight(disabled: Bool = false) -> BlackHighlightButtonStyle {
        BlackHighlightButtonStyle(disabled: disabled)
    }
}
