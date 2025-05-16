// Copyright © 2025 Zama. All rights reserved.

import SwiftUI

//#Preview {
//    ProfileTab()
//}

struct ProfileTab: View {
    @StateObject private var vm = ViewModel()
    
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
                    concreteKeyManagementSection()
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
        Label("Profile info", systemImage: DataVaultTab.profile.displayInfo.icon)
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
            // No data on disk, or stale data
            let showEncryptButton = !vm.profileOnDisk || vm.hasPendingChanges
            let encryptTitle = vm.encryptedClearProfile == nil ? "Encrypt data" : "Re-encrypt data"
            if showEncryptButton {
                AsyncButton(encryptTitle) {
                    try await vm.encryptData()
                }
                .disabled(vm.completedProfile == nil)
            } else {
                let icon2 = Image(systemName: "checkmark.circle.fill")
                Text("\(icon2)\nYour data was successfully encrypted")
                    .customFont(.title3)
                    .multilineTextAlignment(.center)
            
                OpenAppButton(.fheAds)
            }
        }
    }
    
    @ViewBuilder
    private func concreteKeyManagementSection() -> some View {
        VStack(spacing: 10) {
            Text("Concrete ML Key Management")
                .customFont(.title3)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            AsyncButton("Refresh Concrete ML Keys") {
                await vm.refreshConcreteMLKeys()
            }
            .buttonStyle(.zama)
            
            Text("If a FHE friendly app (like FHE Ads) reports issues, use this to ensure your local FHE keys (PrivateKey, PublicKey) are correctly generated and saved.")
                .customFont(.caption)
                .foregroundStyle(.gray)
                .multilineTextAlignment(.leading)
            
            if !vm.concreteKeyRefreshConsoleOutput.isEmpty {
                Button("Clear Key Refresh Log") {
                    vm.concreteKeyRefreshConsoleOutput = ""
                }
                .customFont(.caption)
                .tint(.gray)
                ConsoleSection(title: "Concrete ML Key Refresh Log", output: vm.concreteKeyRefreshConsoleOutput)
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
        @Published var encryptedClearProfile: Profile?
        @Published var hasPendingChanges: Bool

        @Published var profileOnDisk: Bool
        @Published var consoleOutput: String = "Profile Encryption Details:"
        @Published var concreteKeyRefreshConsoleOutput: String = ""
        
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
            self.hasPendingChanges = false
            
            Task {
                do {
                    try await loadKeys()
                } catch {
                    print(error)
                }
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
        
        func refreshConcreteMLKeys() async {
            var log = "Attempting to refresh Concrete ML keys...\n\n"
            concreteKeyRefreshConsoleOutput = log
            do {
                do {
                    try await Storage.deleteFromDisk(.concretePrivateKey)
                    log += "Deleted existing Concrete ML PrivateKey from disk.\n"
                } catch {
                    log += "Could not delete old PrivateKey: \(error.localizedDescription).\n"
                }
                
                let (newPK, _) = try await ConcreteML.generateAndPersistKeys()
                self.pk = newPK
                log += "Successfully regenerated new Concrete ML PrivateKey.\n"
                
                profileOnDisk = false
                encryptedClearProfile = nil
                validateProfile()
                
                if completedProfile != nil {
                    try? await Storage.deleteFromDisk(.concreteEncryptedProfile)
                    log += "Deleted previously encrypted profile data from disk.\n"
                }
                
                log += "Concrete ML key refresh complete.\n"
                concreteKeyRefreshConsoleOutput = log
            } catch {
                log += "Error during Concrete ML key refresh: \(error.localizedDescription)\n"
                concreteKeyRefreshConsoleOutput = log
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
            
            hasPendingChanges = completedProfile != encryptedClearProfile
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
            self.consoleOutput += "Encrypted Profile hash: \(data.stableHashValue)\n\n"
            self.consoleOutput += "Encrypted Profile snippet (first 100 bytes): \(data.snippet(first: 100))\n\n"

            try await Storage.write(.concreteEncryptedProfile, data: data)
            profileOnDisk = true
            encryptedClearProfile = completedProfile
            hasPendingChanges = completedProfile != encryptedClearProfile

            self.consoleOutput += "Saved at \(Storage.url(for: .concreteEncryptedProfile))\n"
        }
    }
}
