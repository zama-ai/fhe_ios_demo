// Copyright © 2025 Zama. All rights reserved.

import SwiftUI

#Preview {
    @Previewable @State var native = false
    NavigationStack {
        if native {
            Color.yellow.overlay {
                Toggle("Native", isOn: $native)
                    .padding()
            }
            .navigationTitle("Main Title")
        } else {
            Color.yellow.overlay {
                Toggle("Native", isOn: $native)
                    .padding()
            }
            .navigationTitleView("Main Title", icon: "cloud.fill")
        }
    }
}

struct NavigationTitleViewModifier: ViewModifier {
    let title: String
    let icon: String
    
    func body(content: Content) -> some View {
        content
            .padding(.top, 52)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("\(Image(systemName: icon)) \(title)")
                        .font(.largeTitle)
                        .imageScale(.small)
                        .bold()
                        .padding(.top, 92)
                }
            }
    }
}

extension View {
    func navigationTitleView(_ title: String, icon: String) -> some View {
        self.modifier(NavigationTitleViewModifier(title: title, icon: icon))
    }
}
