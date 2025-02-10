// Copyright © 2025 Zama. All rights reserved.

import Foundation
import SwiftUI

@MainActor
final class ProfileVM: ObservableObject {
    @Published var editProfile: EditProfile = .init()
    @Published var fullProfile: Profile?
    
    private var pk: PrivateKey?
    private var ck: CpuCompressionKey?
    
    func loadFromDisk() async throws {
        try await loadEncryptionKeysAndParams()
        //        do {
        //            let p = try await Storage.read(.profile)
        //        } catch {
        //            print("Error loading data: \(error)")
        //        }
    }
    
    func getFakeProfile() -> Profile {
        Profile(gender: .male,
                age: .middle_adult,
                language: .english,
                country: .united_states,
                interestedInKids: true,
                interests: [.automobiles, .bicycle])
    }
    
    func getFilledProfile(editProfile: EditProfile) -> Profile? {
        Profile(editProfile: editProfile)
    }
    
    func fillUIWithProfile(_ profile: Profile) {
        fullProfile = profile
    }
    
    func canEncryptData() -> Bool {
        fullProfile != nil
    }
    
    func encryptProfile(_ profile: Profile) async throws -> Data {
        guard let pk, let cryptoParams = Self.cryptoParams else {
            throw NSError(domain: "Cannot encrypt profile", code: 0, userInfo: nil)
        }
        
        let oneHot = [profile.oneHotBinary]
        let encryptedMatrix: EncryptedMatrix = try encryptMatrix(pkey: pk, cryptoParams: cryptoParams, data: oneHot)
        let data = try encryptedMatrix.serialize() // 8 Kb
        return data
    }
    
    func persistEncryptedProfile(_ data: Data) async throws {
        try await Storage.write(.matrixEncryptedProfile, data: data)
    }
    
    /// Load keys  (private + compression) from disk into memory (generating them if needed)
    func loadEncryptionKeysAndParams() async throws {
        do {
            var tmpPK: PrivateKey? = nil
            var tmpCK: CpuCompressionKey? = nil
            
            if let savedPK: Data = await Storage.read(.matrixPrivateKey) {
                tmpPK = await Self.deserializePrivateKey(from: savedPK)
            }
            
            if let savedCK: Data = await Storage.read(.matrixCPUCompressionKey) {
                tmpCK = try await Self.deserializeCompressionKey(from: savedCK)
            }
            
            if tmpPK == nil || tmpCK == nil {
                // One of the keys is missing/bogus, Regen & save both.
                let (pk, ck) = try await Self.generateAndPersistKeys()
                tmpPK = pk
                tmpCK = ck
            }
            
            self.pk = tmpPK
            self.ck = tmpCK
        } catch {
            print("Error: \(error)")
            let (pk, ck) = try await Self.generateAndPersistKeys()
            self.pk = pk
            self.ck = ck
        }
    }
}

// MARK: - Encryption Utilities -
extension ProfileVM {
    static var cryptoParams: MatmulCryptoParameters? = {
        do {
            let jsonParams = defaultParams()
            let cryptoParams: MatmulCryptoParameters = try matmulCryptoParametersDeserialize(content: jsonParams)
            return cryptoParams
        } catch {
            print("Error: \(error)")
            return nil
        }
    }()
    
    static func generateAndPersistKeys() async throws -> (PrivateKey, CpuCompressionKey) {
        try await Task.detached(priority: .high) {
            guard let cryptoParams = await Self.cryptoParams else {
                throw NSError(domain: "Failed to deserialize crypto params", code: 0, userInfo: nil)
            }
            let keys = cpuCreatePrivateKey(cryptoParams: cryptoParams) // 23 sec
            let pk = keys.privateKey()
            let ck = keys.cpuCompressionKey()
            try await Storage.write(.matrixPrivateKey, data: try await serializePrivateKey(pk)) // 33 KB, instant
            try await Storage.write(.matrixCPUCompressionKey, data: try await serializeCompressionKey(ck)) // 67 MB, 2.5s
            return (pk, ck)
        }.value
    }
    
    static func serializePrivateKey(_ privateKey: PrivateKey) async throws -> Data {
        try await Task.detached {
            try privateKey.serialize() // instant
        }.value
    }
    
    static func serializeCompressionKey(_ compressionKey: CpuCompressionKey) async throws -> Data {
        try await Task.detached {
            try compressionKey.serialize() // 2.5 sec
        }.value
    }

    static func deserializePrivateKey(from: Data) async -> PrivateKey {
        await Task.detached {
            privateKeyDeserialize(content: from)
        }.value
    }

    static func deserializeCompressionKey(from: Data) async throws -> CpuCompressionKey {
        try await Task.detached {
            try cpuCompressionKeyDeserialize(content: from)
        }.value
    }
}
