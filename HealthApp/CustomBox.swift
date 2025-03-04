// Copyright © 2025 Zama. All rights reserved.

import SwiftUI

#Preview {
    VStack {
        CustomBox(label: { Text("Label") },
                  onTap: { print("tapped") }) {
            Text("Content A")
            Text("Content B")
        }
        
        CustomBox("String") {
            Text("Content")
        }

        CustomBox("String") {
            Text("Content A")
            Text("Content B")
        }

        Spacer()
    }
    .padding()
    .background(Color.zamaYellow)
}

struct CustomBox<Label: View, Content: View>: View {
    let label: () -> Label
    var onTap: (() -> Void)? = nil
    let content: () -> Content

    init(label: @escaping () -> Label, onTap: (() -> Void)? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.label = label
        self.onTap = onTap
        self.content = content
    }

    init(_ title: String, onTap: (() -> Void)? = nil, @ViewBuilder content: @escaping () -> Content) where Label == Text {
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
