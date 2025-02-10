// Copyright © 2025 Zama. All rights reserved.

import SwiftUI

#Preview {
    ProfileForm(vm: .init())
}

struct ProfileForm: View {
    @StateObject var vm: DataVaultView.ViewModel
    @State private var interests: [Interest] = []
    
    var body: some View {
            Form {
                Section {
                    LabeledContent("Gender") {
                        Picker("Gender", selection: $vm.editProfile.gender) {
                            ForEach(Gender.allCases.reversed(), id: \.self) { item in
                                Text(item.prettyTypeName).tag(item)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    LabeledContent("Age") {
                        Picker("Age", selection: $vm.editProfile.age) {
                            ForEach(AgeGroup.allCases, id: \.self) { item in
                                Text(item.displayName).tag(item)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    // Toggle("Interested In Kids Ads", isOn: $editProfile.interestedInKids)
                    
                    Picker("Interested In", selection: $vm.editProfile.interests) {
                        ForEach(Interest.allCases, id: \.self) { item in
                            Text(item.prettyTypeName).tag(item)
                        }
                    }
                    .pickerStyle(.navigationLink)

                    Picker("Country", selection: $vm.editProfile.country) {
                        let sorted = Country.allCases.sorted(by: { $0.localizedCountryName < $1.localizedCountryName })
                        ForEach(sorted, id: \.self) { item in
                            Text("\(item.flag) \(item.localizedCountryName)")
                                .tag(item)
                        }
                    }
                    .pickerStyle(.navigationLink)
                    
                    Picker("Language", selection: $vm.editProfile.language) {
                        let sorted = Language.allCases.sorted(by: { $0.languageNames.native < $1.languageNames.native })
                        ForEach(sorted, id: \.self) { item in
                            Text("\(item.languageNames.native) (\(item.languageNames.translated))")
                                .tag(item)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }                
        }
    }
}
