// Copyright © 2024 Zama. All rights reserved.

import SwiftUI

extension View {
    func privateDataRing() -> some View {
        self.modifier(PrivateDataRing())
    }
}

private struct PrivateDataRing: ViewModifier {
    @State private var showDisclaimer = false
    
    func body(content: Content) -> some View {
        content
            .padding(24)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(.yellow, lineWidth: 2)
            )
            .padding(8)
            .overlay(alignment: .topTrailing) {
                seal.offset(x: 1)
            }
    }
    
    private var seal: some View {
        Button(action: {
            showDisclaimer = true
        }, label: {
            Image(systemName: "checkmark.seal.fill")
                .bold()
                .foregroundStyle(.green)
                .background {
                    Circle().fill(.black).padding(4)
                }
                .shadow(radius: 3)
                .padding(2)
        })
        .buttonStyle(.plain) // So that it works when embedded in Lists
        .fullScreenCover(isPresented: $showDisclaimer) {
            DisclaimerSheet(isPresented: $showDisclaimer)
                .padding(.horizontal, 4)
        }
    }
}

private struct DisclaimerSheet: View {
    @Binding var isPresented: Bool
    @Environment(\.openURL) private var openURL

    var body: some View {
        GroupBox {
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "lock.rectangle.on.rectangle.fill")
                        .foregroundStyle(.yellow)
                    Text("This Data is Private")
                }
                .font(.title2)
                
                Text("The app can't read this information.\nOnly you have visibility.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                
                Button("Learn more on Zama.ai") {
                    openURL(URL(string: "https://www.zama.ai")!)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .overlay(alignment: .topTrailing) {
            closeButton
        }
    }
    
    private var closeButton: some View {
        Button {
            isPresented.toggle()
        } label: {
            Image(systemName: "xmark")
                .frame(width: 44, height: 44)
        }
        .foregroundStyle(.secondary)
    }
}

#Preview {
    VStack {
        Text("This data is private")
            .privateDataRing()

        Text("This one also")
            .privateDataRing()
        
        DisclaimerSheet(isPresented: .constant(true))
        
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(40)), count: 5)) {
            let icons: [String] = [
                "lock.fill",
                "lock.open.fill",
                "lock.rectangle.fill",
                "lock.rectangle.on.rectangle.fill", // here
                "lock.shield.fill",
                "eye.slash.fill",
                "eyes",
                "figure.child.and.lock.fill",
                "figure.child.and.lock.open.fill",
                "checkmark.seal.fill", // here
                "shield.lefthalf.filled.badge.checkmark",
                "checkmark.circle.fill",
                "checkmark.shield.fill",
                "person.badge.shield.checkmark.fill",
                "person.crop.circle.fill.badge.checkmark",
            ]
            ForEach(icons, id: \.self) {
                Image(systemName: $0)
                    .font(.title)
                    .foregroundStyle(.yellow)
                    .padding(4)
            }
        }
        .padding(.top, 30)
    }
}
