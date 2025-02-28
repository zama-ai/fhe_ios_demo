// Copyright © 2025 Zama. All rights reserved.

import SwiftUI

#Preview {
    Text("salut")
    //ProfileForm2()
        .preferredColorScheme(.light)
}

struct ProfileForm2: View {
//    @StateObject var vm: ProfileVM = .init()
//    @State private var editProfile: EditProfile = .init()
    @State private var age: String = ""
    @State private var selection: Int? = nil

    var body: some View {
        VStack {
            Text("\(Image(systemName: "person.crop.circle")) Profile Info")
                .customFont(.title)
                .bold()
            
            Button("Generate data sample") {}
                .buttonStyle(.fullWidth)

            Text("or fill in info below")
            
            Section("Demographics") {
                //form
                TagsGridView()
                TextField("Last name", text: .constant("")).textFieldStyle(.automatic)
                TextField("Last name", text: .constant("")).textFieldStyle(.roundedBorder)
            }

            Button("Encrypt data") {}
                .buttonStyle(.fullWidth)
                .disabled(true)
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .buttonStyle(.borderedProminent)
    }
    
    @ViewBuilder
    var form: some View {
        LabeledContent("Age") {
            TextField("", text: $age)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.numberPad)
        }

        LabeledContent("Gender") {
            Picker("", selection: $selection) {
                Text("Male").tag(1)
                Text("Female").tag(2)
            }.pickerStyle(.palette)
        }
        
        Menu {
            Button("Option 1", action: { print("Selected Option 1") })
            Button("Option 2", action: { print("Selected Option 2") })
            Button("Option 3", action: { print("Selected Option 3") })
        } label: {
            Label("Show Menu", systemImage: "ellipsis.circle")
        }
        .menuStyle(.borderlessButton)

        Button("sss") {}
            .contextMenu {
                Text("Male").tag(1)
                Text("Female").tag(2)
                Text("aa").tag(3)
                Text("FFFF").tag(4)
                Text("FFFF").tag(5)
                Text("FFFF").tag(6)
                Text("FFFF").tag(7)
            }
        LabeledContent("Gender") {
            Picker("", selection: $selection) {
                Text("Male").tag(1)
                Text("Female").tag(2)
                Text("aa").tag(3)
                Text("FFFF").tag(4)
                Text("FFFF").tag(5)
                Text("FFFF").tag(6)
                Text("FFFF").tag(7)
            }
            .pickerStyle(.menu)
            .frame(width: .infinity)
        }
    }
}

struct TagsGridView: View {
    let lines = Interest.allCases.map(\.prettyTypeName).chunks(ofCount: 4)

    var body: some View {
        VStack {
            ForEach(lines, id: \.self) { line in
                HStack {
                    ForEach(line, id: \.self) { word in
                        Text(word)
                            .bold()
                            .padding(8)
                            .background(Color.gray.opacity(0.2))
                    }
                }
            }
        }
    }
}

struct FullWidthButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(10)
            .frame(maxWidth: .infinity) // Full width
            .background(.zamaYellow.opacity(configuration.isPressed || !isEnabled ? 0.25 : 1))
            .foregroundColor(.black)
            .customFont(.headline)
            .border(configuration.isPressed ? .black : .clear, width: 1)
            .opacity(configuration.isPressed ? 0.5 : 1.0)
            .animation(.spring(), value: configuration.isPressed) // Animated press effect
    }
}

// Extend ButtonStyle to support .fullWidth
extension ButtonStyle where Self == FullWidthButtonStyle {
    static var fullWidth: FullWidthButtonStyle {
        return FullWidthButtonStyle()
    }
}
