// Copyright © 2025 Zama. All rights reserved.

import Foundation
import Security

struct KeychainHelper {
    enum KeychainError: LocalizedError {
        case failedToCompressData
        case failedToDecompressData
        case failedToAddToKeychain(status: OSStatus)
        case failedToReadFromKeychain(status: OSStatus)
    }
    
    enum Key: String {
        case tfheClientKey = "v11.tfheClientKey"
        case concretePrivateKey = "v11.concretePrivateKey"
        
        var sharedKeychainAccessGroup: String {
            let teamID = "2FFZB9H65L"
            switch self {
            case .tfheClientKey: return "\(teamID).ai.zama.fhedemo.sharedkeychain.health"
            case .concretePrivateKey: return "\(teamID).ai.zama.fhedemo.sharedkeychain.ads"
            }
        }
    }
    
    static func storeSharedData(_ data: Data, for key: Key) throws {
        guard let compressedData = CompressionHelper.compressLZFSE(data) else {
            throw KeychainError.failedToCompressData
        }
        
        print("KEYCHAIN write: ", data.formattedSize)
        print("KEYCHAIN write: ", compressedData.formattedSize)
        
        let query: [String: Any] = [
            kSecClass as String:              kSecClassGenericPassword,
            kSecAttrAccount as String:        key.rawValue,
            kSecAttrAccessGroup as String:    key.sharedKeychainAccessGroup,
            kSecValueData as String:          compressedData,
            kSecAttrAccessible as String:     kSecAttrAccessibleWhenUnlockedThisDeviceOnly // Only store this on this device, and don’t back it up. Wipe it if the app is deleted.
        ]
        
        // Delete existing if exists
        SecItemDelete(query as CFDictionary)
        
        // Add new
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.failedToAddToKeychain(status: status)
        }
    }
    
    static func readSharedData(_ key: Key) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String:            kSecClassGenericPassword,
            kSecAttrAccount as String:      key.rawValue,
            kSecAttrAccessGroup as String:  key.sharedKeychainAccessGroup,
            kSecReturnData as String:       true,
            kSecMatchLimit as String:       kSecMatchLimitOne
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status == errSecSuccess else {
            throw KeychainError.failedToReadFromKeychain(status: status)
        }
        
        guard let compressed = item as? Data, let result = CompressionHelper.decompressLZFSE(compressed) else {
            throw KeychainError.failedToDecompressData
        }
        
        print("KEYCHAIN read: ", result.formattedSize)

        return result
    }
}
