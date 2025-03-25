// Copyright © 2025 Zama. All rights reserved.

import SwiftUI

//#Preview {
//    ProfileTab()
//}

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
                    buttonsArea()
                    ConsoleSection(title: "FHE Encryption", output: vm.consoleOutput)
                    Spacer()
                }
                .padding(.horizontal, 30)
            }
            .scrollDismissesKeyboard(.immediately)
            .scrollBounceBehavior(.basedOnSize)
        }
        .customFont(.body)
        .buttonStyle(.zama)
        .onChange(of: vm.age, vm.validateProfile)
        .onChange(of: vm.gender, vm.validateProfile)
        .onChange(of: vm.country, vm.validateProfile)
        .onChange(of: vm.language, vm.validateProfile)
        .onChange(of: vm.interests, vm.validateProfile)
        .onAppearAgain {
            vm.refreshFromDisk()
        }
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
            
            TagsGrid(items: Interest.allCasesPlusKids, chunkedBy: 4, selection: $vm.interests) { interest, isSelected in
                Text(interest.prettyTypeName)
                    .bold()
                    .padding(6)
                    .background(isSelected ? .black : .gray.opacity(0.2))
                    .foregroundStyle(isSelected ? .white : .black)
            }.buttonStyle(.plain)
        }
    }
    
    @ViewBuilder
    private func buttonsArea() -> some View {
        VStack {
            AsyncButton("Encrypt data") {
                justSaved = false
                try await vm.encryptData()
                justSaved = true
            }
            .disabled(vm.completedProfile == nil)
            
            
            if vm.profileOnDisk {
                if justSaved {
                    let icon2 = Image(systemName: "checkmark.circle.fill")
                    Text("\(icon2)\nYour data was successfully encrypted")
                        .customFont(.title3)
                        .multilineTextAlignment(.center)
                }
                
                OpenAppButton(.fheAds)
            }
        }
    }    
}

extension ProfileTab {
    @MainActor final class ViewModel: ObservableObject {
        @Published var age: String
        @Published var gender: Gender?
        @Published var country: Country?
        @Published var language: Language?
        @Published var interests: Set<Interest>
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
        
        func refreshFromDisk() {
            Task {
                let data = await Storage.read(.concreteEncryptedProfile)
                self.profileOnDisk = data != nil
            }
        }
        
        func generateDataSample() {
            self.age = "35"
            self.gender = .female
            self.country = .france
            self.language = .english
            self.interests = [.health, .nature, .video_games, .sports]
        }
        
        func validateProfile() {
            guard let age = Int(self.age)  else {
                completedProfile = nil
                return
            }
            
            completedProfile = Profile(ageGroup: AgeGroup(age: age),
                                       gender: self.gender,
                                       country: self.country,
                                       language: self.language,
                                       interests: self.interests)
        }
        
        func encryptData() async throws {
            self.consoleOutput = ""
            self.consoleOutput += "Encrypting profile…\n\n"
            
            guard let pk, let cryptoParams = ConcreteML.cryptoParams, let completedProfile else {
                throw NSError(domain: "Cannot encrypt profile", code: 0, userInfo: nil)
            }
            
            let profileLogged = String(describing: completedProfile)
                .replacingOccurrences(of: "ZAMA_Data_Vault.", with: "")
                .replacingOccurrences(of: "Interests.", with: "")
                .replacingOccurrences(of: ", ", with: ",\n  ")
            
            self.consoleOutput += "\(profileLogged)\n\n"
            self.consoleOutput += "Crypto Params: \(ConcreteML.cryptoParamsString ?? "nil")\n\n"
            
            let oneHot = [completedProfile.oneHotBinary]
            self.consoleOutput += "OneHot: \(oneHot)\n\n"
            
            let encryptedMatrix: EncryptedMatrix = try encryptMatrix(pkey: pk, cryptoParams: cryptoParams, data: oneHot)
            let data = try encryptedMatrix.serialize() // 8 Kb
            
            self.consoleOutput += "Encrypted Profile: \(data.formattedSize)\n\n"
            self.consoleOutput += "Encrypted Profile hash: \(data.persistantHashValue)\n\n"

            try await Storage.write(.concreteEncryptedProfile, data: data)
            profileOnDisk = true
            
            self.consoleOutput += "Saved at \(Storage.url(for: .concreteEncryptedProfile))\n"
        }
        
        func delete() async throws {
            try await Storage.deleteFromDisk(.concreteEncryptedProfile)
            profileOnDisk = false
            completedProfile = nil
        }
    }
}
