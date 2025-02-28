// Copyright © 2025 Zama. All rights reserved.

import Foundation
import SwiftUI

@MainActor
final class ProfileVM: ObservableObject {
    @Published var editProfile: EditProfile {
        didSet {
            fullProfile = Profile(from: editProfile)
        }
    }
    @Published var fullProfile: Profile?
    @Published var profileOnDisk: Bool
    private var pk: PrivateKey?

    init() {
        self.editProfile = EditProfile()
        self.fullProfile = nil
        self.profileOnDisk = false
        Task {
            try await self.loadKeys()
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

    func encrypt() async throws {
        guard let pk, let cryptoParams = ConcreteML.cryptoParams, let fullProfile else {
            throw NSError(domain: "Cannot encrypt profile", code: 0, userInfo: nil)
        }
        
        let oneHot = [fullProfile.oneHotBinary]
        let encryptedMatrix: EncryptedMatrix = try encryptMatrix(pkey: pk, cryptoParams: cryptoParams, data: oneHot)
        let data = try encryptedMatrix.serialize() // 8 Kb
        
        try await Storage.write(.concreteEncryptedProfile, data: data)
        profileOnDisk = true
    }
    
    func delete() async throws {
        try await Storage.deleteFromDisk(.concreteEncryptedProfile)
        profileOnDisk = false
        editProfile = EditProfile()
    }
}
