// Copyright © 2025 Zama. All rights reserved.

import Foundation

final class Storage {
    enum File: String, CaseIterable {
        case clientKey = "clientKey"
        case publicKey = "publicKeyCompact"
        case serverKey = "serverKeyCompressed"

        case concretePrivateKey = "concretePrivateKey"
        case concreteCPUCompressionKey = "concreteCPUCompressionKey"
        case concreteEncryptedProfile = "concreteProfile.fheencrypted"
        case concreteEncryptedResult = "concreteResult.fheencryptedAd"

        case weightList = "weightList.fheencrypted"
        case weightMin = "weightMin.fheencrypted"
        case weightMax = "weightMax.fheencrypted"
        case weightAvg = "weightAvg.fheencrypted"
        
        case sleepList = "sleepList.fheencrypted"
        case sleepScore = "sleepScore.fheencrypted"

        var decryptType: DecryptType? {
            switch self {
            case .sleepList: .cipherTextList
            case .sleepScore: .int8
                
            case .weightList: .array
            case .weightMin, .weightMax, .weightAvg:  .int16
                
            case .clientKey, .publicKey, .serverKey: nil
            case .concretePrivateKey, .concreteCPUCompressionKey,
                    .concreteEncryptedProfile, .concreteEncryptedResult: nil
            }
        }
        
        enum DecryptType {
            case int8, int16, array, cipherTextList
        }
        
        func withSuffix(_ suffix: String?) -> String {
            guard let suffix, !suffix.isEmpty else { return self.rawValue }

            let components = rawValue.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
            if components.count == 2 {
                return "\(components[0])-\(suffix).\(components[1])"
            } else {
                return "\(rawValue)-\(suffix)"
            }
        }
    }
    
    private init() {
        print("🗂️🗂️ Shared Folder: 🗂️🗂️\nopen \(sharedFolder)")
    }
    
    private static let singleton = Storage()
    
    /// Pass nil to delete file
    static func write(_ file: File, data: Data?, suffix: String? = nil) async throws {
        let fileName = file.withSuffix(suffix)
        let fullURL = singleton.sharedFolder.appendingPathComponent(fileName)
        try await singleton.write(at: fullURL, data: data)
    }
    
    static func write(_ url: URL, data: Data?) async throws {
        try await singleton.write(at: url, data: data)
    }
    
    static func deleteFromDisk(_ file: Storage.File) async throws {
        try await Storage.write(file, data: nil)
    }
    
    /// Returns nil if file missing
    static func read(_ file: File) async -> Data? {
        let fullURL = singleton.sharedFolder.appendingPathComponent(file.rawValue)
        return await singleton.read(at: fullURL)
    }
    
    static func read(_ url: URL) async -> Data? {
        await singleton.read(at: url)
    }
    
    static func url(for file: File, suffix: String? = nil) -> URL {
        let fileName = file.withSuffix(suffix)
        return singleton.sharedFolder.appendingPathComponent(fileName)
    }
}

extension Storage {
    private func write(at url: URL, data: Data?) async throws {
        let fileName = url.lastPathComponent
        if let data {
            try await withCheckedThrowingContinuation { continuation in
                Task(priority: .utility) {
                    do {
                        print("💾 Writing \(fileName) (\(data.formattedSize))")
                        try data.write(to: url, options: .atomic)
                        continuation.resume()
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        } else {
            print("❌ Deleting \(fileName)")
            try FileManager.default.removeItem(at: url)
        }
    }
    
    private func read(at url: URL) async -> Data? {
        let fileName = url.lastPathComponent
        
        return await withCheckedContinuation { continuation in
            Task(priority: .utility) {
                do {
                    print("👀 Reading \(fileName)")
                    let data = try Data(contentsOf: url)
                    continuation.resume(returning: data)
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    private var sharedFolder: URL {
        let appGroup = "group.ai.zama.fhedemo.shared"
        guard let folder = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) else {
            fatalError("No shared folder - AppGroup misconfigured")
        }
        return folder
    }
}

extension Data {
    var formattedSize: String {
        self.count.formatted(.byteCount(style: .file))
    }
}
