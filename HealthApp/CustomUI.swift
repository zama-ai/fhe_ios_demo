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
        
        CustomBox(label: { Text("Section Label") },
                  onTap: { print("tapped") },
                  content: { Text("Section Content") }
        )
        
        CustomBox(label: { Text("Section Label") },
                  content: { Text("Section Content") }
        )
        Spacer()
    }
    .padding()
    .background(.zamaBackgroundPage)
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

struct CustomBox<Label: View, Content: View>: View {
    let label: () -> Label
    var onTap: (() -> Void)? = nil
    let content: () -> Content

    init(label: @escaping () -> Label, onTap: (() -> Void)? = nil, content: @escaping () -> Content) {
        self.label = label
        self.onTap = onTap
        self.content = content
    }

    init(_ title: String, onTap: (() -> Void)? = nil, content: @escaping () -> Content) where Label == Text {
        self.label = { Text(title) }
        self.onTap = onTap
        self.content = content
    }

    var body: some View {
        Button {
            onTap?()
        } label: {
            VStack(alignment: .leading) {
                HStack {
                    label()
                    if let _ = onTap {
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                }
                .font(.title3)
                .fontWeight(.heavy)
                .foregroundStyle(.black)
                
                Divider()
                    .frame(height: 2)
                    .background(.black)
                
                content()
            }
            .frame(minHeight: 100, alignment: .top)
            .padding()
            .background(Color.white)
            .fontWeight(.medium)
            .contentShape(Rectangle())
        }
        .buttonStyle(.blackHighlight(disabled: onTap == nil))
    }
}
