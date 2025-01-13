// Copyright © 2024 Zama. All rights reserved.

import SwiftUI

#Preview {
    ProfileForm(vm: .init())
}

struct ProfileForm: View {
    @StateObject var vm: DataVaultView.ViewModel
    @State private var editProfile: EditProfile = .init()
    @State private var interests: [Interest] = []
    
    var body: some View {
        NavigationStack {
            
            Form {
                Section {
                    LabeledContent("Gender") {
                        Picker("Gender", selection: $editProfile.gender) {
                            ForEach(Gender.allCases.reversed(), id: \.self) { item in
                                Text(item.displayName).tag(item)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    LabeledContent("Age") {
                        Picker("Age", selection: $editProfile.age) {
                            ForEach(AgeGroup.allCases, id: \.self) { item in
                                Text(item.displayName).tag(item)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    Toggle("Interested In Kids Ads", isOn: $editProfile.interestedInKids)
                    
                    Picker("Interested In", selection: $editProfile.interests) {
                        ForEach(Interest.allCases, id: \.self) { item in
                            Text(item.displayName).tag(item)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }
                
                Section {
                    Picker("Country", selection: $editProfile.country) {
                        let sorted = Country.allCases.sorted(by: { $0.localizedCountryName < $1.localizedCountryName })
                        ForEach(sorted, id: \.self) { item in
                            Text("\(item.flag) \(item.localizedCountryName)")
                                .tag(item)
                        }
                    }
                    .pickerStyle(.navigationLink)
                    
                    Picker("Language", selection: $editProfile.language) {
                        let sorted = Language.allCases.sorted(by: { $0.languageName.local < $1.languageName.local })
                        ForEach(sorted, id: \.self) { item in
                            Text("\(item.languageName.local) (\(item.languageName.translated))").tag(item)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }
                
                Section("OneHot") {
                    if let profile = Profile(editProfile: editProfile) {
                        Text("\(profile.oneHotBinary)")
                    } else {
                        Text("Fill all mandatory fields")
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}
