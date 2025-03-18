// Copyright © 2025 Zama. All rights reserved.

import SwiftUI

#Preview {
    ProfileTab()
}

struct ProfileTab: View {
    @StateObject private var vm = ViewModel()
    @State private var justSaved: Bool = false
    private let tabType: DataVaultTab = .profile

    var body: some View {
        VStack(spacing: 0) {
            header()
                .padding(.horizontal, 30)
                .padding(.bottom, 30)

            ScrollView {
                VStack(spacing: 24) {
                    topInstructions()
                    demographics()
                    interestsGrid()
                    encryptExportArea()
                    consoleArea()
                    Spacer()
                }
                .padding(.horizontal, 30)
            }
            .scrollDismissesKeyboard(.immediately)
        }
        .customFont(.body)
        .buttonStyle(.zama)
        .onChange(of: vm.age, vm.validateProfile)
        .onChange(of: vm.gender, vm.validateProfile)
        .onChange(of: vm.country, vm.validateProfile)
        .onChange(of: vm.language, vm.validateProfile)
        .onChange(of: vm.interests, vm.validateProfile)
    }
    
    @ViewBuilder
    private func header() -> some View {
        Label("Profile info", systemImage: tabType.displayInfo.icon)
            .frame(maxWidth: .infinity, alignment: .leading)
            .customFont(.largeTitle)
    }
    
    @ViewBuilder
    private func topInstructions() -> some View {
        VStack(spacing: 10) {
            Button("Generate data sample", action: vm.generateDataSample)
            Text("or fill in info below")
        }
    }
    
    @ViewBuilder
    private func demographics() -> some View {
        VStack {
            Text("Demographics")
                .frame(maxWidth: .infinity, alignment: .leading)
                .customFont(.title3)

            LabeledContent("Age:") {
                TextField("", text: $vm.age)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.plain)
                    .padding(8)
                    .background(Color.zamaGreyBackground)
            }
            
            LabeledContent("Gender:") {
                Picker("", selection: $vm.gender) {
                    Text("Male").tag(Gender.male)
                    Text("Female").tag(Gender.female)
                }
                .pickerStyle(.segmented)
            }
            
            LabeledContent("Country:") {
                Menu {
                    let sorted = Country.allCases.sorted(by: { $0.localizedCountryName < $1.localizedCountryName })
                    ForEach(sorted, id: \.self) { item in
                        Button("\(item.flag) \(item.localizedCountryName)") { vm.country = item }
                    }
                } label: {
                    Color.zamaGreyBackground
                        .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
                        .overlay(alignment: .leading) {
                            if let country = vm.country {
                                Text("\(country.flag) \(country.localizedCountryName)")
                                    .padding(10)
                                    .tint(.primary)
                            }
                        }
                }
            }
            .menuStyle(.borderlessButton)

            LabeledContent("Language:") {
                Menu {
                    let sorted = Language.allCases.sorted(by: { $0.names.native < $1.names.native })
                    ForEach(sorted, id: \.self) { item in
                        Button("\(item.names.native) (\(item.names.translated))") { vm.language = item }
                    }
                } label: {
                    Color.zamaGreyBackground
                        .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
                        .overlay(alignment: .leading) {
                            if let language = vm.language {
                                Text("\(language.names.native) (\(language.names.translated))")
                                    .padding(10)
                                    .tint(.primary)
                            }
                        }
                }
            }
            .menuStyle(.borderlessButton)
        }
    }
    
    @ViewBuilder
    private func interestsGrid() -> some View {
        VStack {
            Text("Interests")
                .frame(maxWidth: .infinity, alignment: .leading)
                .customFont(.title3)
            
            TagsGrid(items: Interest.allCases.map(\.prettyTypeName), chunkedBy: 4, selection: $vm.interests) { word, isSelected in
                Text(word)
                    .bold()
                    .padding(6)
                    .background(isSelected ? .black : .gray.opacity(0.2))
                    .foregroundStyle(isSelected ? .white : .black)
            }.buttonStyle(.plain)
        }
    }
    
    @ViewBuilder
    private func encryptExportArea() -> some View {
        VStack {
            AsyncButton("Encrypt data") {
                try await vm.encryptData()
                justSaved = true
                try await Task.sleep(for: .seconds(3))
                justSaved = false
            }
            .disabled(vm.completedProfile == nil)
            
            
            if vm.profileOnDisk {
                if justSaved {
                    let icon2 = Image(systemName: "checkmark.circle.fill")
                    Text("\(icon2)\nYour data was successfully encrypted")
                        .customFont(.title3)
                        .multilineTextAlignment(.center)
                }
                
                OpenAppButton(.fheAds) {
                    Text("Export data on FHE Ads")
                }
                
//                AsyncButton(action: vm.delete) {
//                    Image(systemName: "trash")
//                }
//                .foregroundStyle(.red)
            }
        }
    }

    @ViewBuilder
    private func consoleArea() -> some View {
        VStack {
            Text("FHE Encryption")
                .frame(maxWidth: .infinity, alignment: .leading)
                .customFont(.title3)
            
            TextEditor(text: $vm.consoleOutput)
                .padding(8)
                .scrollContentBackground(.hidden)
                .background(Color.zamaGreyConsole)
                .frame(minHeight: 200)
        }
    }
}

extension ProfileTab {
    @MainActor final class ViewModel: ObservableObject {
        @Published var age: String
        @Published var gender: Gender?
        @Published var country: Country?
        @Published var language: Language?
        @Published var interests: Set<String> // TODO: add Kids
        @Published var completedProfile: Profile?
        
        @Published var profileOnDisk: Bool
        @Published var consoleOutput: String = "No data to encrypt."
        private var pk: PrivateKey?

        init() {
            let deviceLanguage = Locale.preferredLanguages.first?.split(separator: "-").first.flatMap(String.init) // e.g., "en-US"
            let deviceCountry = Locale.current.region?.identifier // e.g., "US"

            self.age = ""
            self.gender = nil
            self.country = deviceCountry.flatMap(Country.init(rawValue:)) ?? .united_states
            self.language = deviceLanguage.flatMap(Language.init(rawValue:)) ?? .english
            self.interests = []
            self.completedProfile = nil
                        
            self.profileOnDisk = false
            
            Task {
                await refreshFromDisk()
                try await loadKeys()
            }
        }
        
        private func loadKeys() async throws {
            if let savedPK = await Storage.read(.concretePrivateKey) {
                self.pk = await ConcreteML.deserializePrivateKey(from: savedPK)
            } else {
                let (newPK, _) = try await ConcreteML.generateAndPersistKeys()
                self.pk = newPK
            }
        }

        func refreshFromDisk() async {
            let data = await Storage.read(.concreteEncryptedProfile)
            self.profileOnDisk = data != nil
        }
        
        func generateDataSample() {
            self.age = "35" // FIXME String // Int
            self.gender = .female
            self.country = .france
            self.language = .english
            self.interests = ["Health", "Nature", "Video Games", "Sports"] // FIXME String // Interest
        }
        
        func validateProfile() {
            completedProfile = Profile(age: Int(self.age),
                                       gender: self.gender,
                                       country: self.country,
                                       language: self.language,
                                       interests: Set(self.interests.compactMap { Interest(rawValue: $0) })) // FIXME: convert to/from displayed value
        }
        
        func encryptData() async throws {
            guard let pk, let cryptoParams = ConcreteML.cryptoParams, let completedProfile else {
                throw NSError(domain: "Cannot encrypt profile", code: 0, userInfo: nil)
            }
            
            let oneHot = [completedProfile.oneHotBinary]
            let encryptedMatrix: EncryptedMatrix = try encryptMatrix(pkey: pk, cryptoParams: cryptoParams, data: oneHot)
            let data = try encryptedMatrix.serialize() // 8 Kb
            
            try await Storage.write(.concreteEncryptedProfile, data: data)
            profileOnDisk = true
        }
        
//        func delete() async throws {
//            try await Storage.deleteFromDisk(.concreteEncryptedProfile)
//            profileOnDisk = false
//            editProfile = EditProfile()
//        }
    }
}

