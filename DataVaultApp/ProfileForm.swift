// Copyright © 2025 Zama. All rights reserved.

import SwiftUI

#Preview {
    ProfileForm()
}

struct ProfileForm: View {
    @StateObject var vm = ProfileVM()
    @State private var interests: [Interest] = []
    @State private var justSaved: Bool = false

    var body: some View {
        Form {
            formSection
            encryptSection
        }
    }
    
    private var formSection: some View {
        Section {
            LabeledContent("Gender") {
                Picker("Gender", selection: $vm.editProfile.gender) {
                    ForEach(Gender.allCases.reversed(), id: \.self) { item in
                        Text(item.prettyTypeName).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
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
                    Text("\(item.rawValue) \(item.prettyTypeName)").tag(item)
                }
            }
            
            Picker("Country", selection: $vm.editProfile.country) {
                let sorted = Country.allCases.sorted(by: { $0.localizedCountryName < $1.localizedCountryName })
                ForEach(sorted, id: \.self) { item in
                    Text("\(item.flag) \(item.localizedCountryName)")
                        .tag(item)
                }
            }
            
            Picker("Language", selection: $vm.editProfile.language) {
                let sorted = Language.allCases.sorted(by: { $0.languageNames.native < $1.languageNames.native })
                ForEach(sorted, id: \.self) { item in
                    Text("\(item.languageNames.native) (\(item.languageNames.translated))")
                        .tag(item)
                }
            }
        }
        .buttonStyle(.bordered)
    }
    
    @ViewBuilder
    private var encryptSection: some View {
        Section(content: {
            AsyncButton(action: {
                try await vm.encrypt()
                justSaved = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    justSaved = false
                }
            }, label: {
                let icon = Image(systemName: "arrow.trianglehead.2.clockwise")
                Text("\(icon)  Encrypt Profile")
            }).disabled(vm.fullProfile == nil)
            
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .trailing) {
                if vm.profileOnDisk {
                    AsyncButton(action: vm.delete) {
                        Image(systemName: "trash")
                    }
                    .foregroundStyle(.red)
                }
            }
        }, footer: {
            if vm.fullProfile == nil {
                Text("Fill all mandatory fields")
            }
            if justSaved {
                HStack {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    Text("Profile successfully encrypted")
                }
            }
        }).buttonStyle(.borderless)
        
        Section {
            if vm.profileOnDisk {
                OpenAppButton(.fheAds)
                    .buttonStyle(.borderedProminent)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }
}
