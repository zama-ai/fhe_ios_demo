// Copyright © 2025 Zama. All rights reserved.

import Foundation

/// ConcreteML keygen and encryption utilities, used by both `DataVault` app and `AdsQuickLook` extension binaries
enum ConcreteML {
    static var cryptoParamsString: String? = {
        do {
            let jsonString = defaultParams()
            var asJSON = try JSONSerialization.jsonObject(with: jsonString.data(using: .utf8)!, options: []) as! [String: Any]
            asJSON["bits_reserved_for_computation"] = 11
            let asData = try JSONSerialization.data(withJSONObject: asJSON, options: [.prettyPrinted])
            let newParams = String(data: asData, encoding: .utf8)!
            return newParams
        } catch {
            print("Error: \(error)")
            return nil
        }
    }()
    
    static var cryptoParams: MatmulCryptoParameters? = {
        do {
            if let cryptoParamsString {
                let cryptoParams: MatmulCryptoParameters = try matmulCryptoParametersDeserialize(content: cryptoParamsString)
                return cryptoParams
            }
            return nil
        } catch {
            print("Error: \(error)")
            return nil
        }
    }()
    
    static func generateAndPersistKeys() async throws -> (PrivateKey, CpuCompressionKey) {
        try await Task.detached(priority: .high) {
            guard let cryptoParams = Self.cryptoParams else {
                throw NSError(domain: "Failed to deserialize crypto params", code: 0, userInfo: nil)
            }
            let keys = cpuCreatePrivateKey(cryptoParams: cryptoParams) // 23 sec
            let pk = keys.privateKey()
            let ck = keys.cpuCompressionKey()
            try await Storage.write(.concretePrivateKey, data: try await serializePrivateKey(pk)) // 33 KB, instant
            try await Storage.write(.concreteCPUCompressionKey, data: try await serializeCompressionKey(ck)) // 67 MB, 2.5s
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
}
