// Copyright © 2024 Zama. All rights reserved.

import SwiftUI

#Preview {
    ProfileForm(vm: .init())
        .padding()
        .background {
            Color.gray.opacity(0.5)
                .cornerRadius(8)
        }
}

/*
 Vector:
- interests: QCM
- age: 5 ranges
- gender
- kids, marital
- languages/country

 
 Ad:
 titre
 description
 image: 1024x1024
 */


struct ProfileForm: View {
    @StateObject var vm: DataVaultView.ViewModel
    @FocusState private var focus: Field?

    enum Field: Hashable {
        case name, sex, age, interests
    }

    var body: some View {
        VStack {
            let margin = 80.0
            TextField("Name", text: Binding($vm.clearProfileName, default: ""))
                .textContentType(.name)
                .focused($focus, equals: .name)
                .submitLabel(.next) // Show "Next" button on keyboard
                .onSubmit {
                    focus = .sex
                }
                .padding(.leading, margin)
                .overlay(alignment: .leading) {
                    Text("Name")
                }
            
            TextField("Sex", text: Binding($vm.clearProfileSex, default: ""))
                .focused($focus, equals: .sex)
                .submitLabel(.next) // Show "Next" button on keyboard
                .onSubmit {
                    focus = .age
                }
                .padding(.leading, margin)
                .overlay(alignment: .leading) {
                    Text("Sex")
                }
            
            TextField("Age", text: Binding($vm.clearProfileAge, default: ""))
                .focused($focus, equals: .age)
                .submitLabel(.next) // Show "Next" button on keyboard
                .onSubmit {
                    focus = .interests
                }
                .padding(.leading, margin)
                .overlay(alignment: .leading) {
                    Text("Age")
                }
            
            TextField("Interests", text: Binding($vm.clearProfileInterests, default: ""))
                .focused($focus, equals: .interests)
                .submitLabel(.done)
                .onSubmit {
                    focus = nil
                }
                .padding(.leading, margin)
                .overlay(alignment: .leading) {
                    Text("Interests")
                }
                .padding(.bottom, 12)
        }
        .textFieldStyle(.roundedBorder)
    }
}

extension Binding {
    init(_ optional: Binding<Value?>, default defaultValue: Value) {
        self.init(
            get: { optional.wrappedValue ?? defaultValue },
            set: { newValue in optional.wrappedValue = newValue }
        )
    }
}
