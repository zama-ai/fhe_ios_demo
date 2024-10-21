// Copyright © 2024 Zama. All rights reserved.

import Foundation

final class Storage {
    enum File: String {
        case clientKey = "clientKey"
        case publicKey = "publicKeyCompact"
        case serverKey = "serverKeyCompressed"
        case serverKeyUncompressed = "serverKey.uncompressed"

        case encryptedInputInt  = "inputInt.fheencrypted"
        case encryptedInputList  = "inputList.fheencrypted"
        
        case encryptedOutputMin = "outputMin.fheencrypted"
        case encryptedOutputMax = "outputMax.fheencrypted"
        case encryptedOutputAvg = "outputAvg.fheencrypted"
    }
    
    private init() {
        print("🗂️🗂️ Shared Folder: 🗂️🗂️\nopen \(sharedFolder)")
    }
    
    private static let singleton = Storage()
    
    /// Pass nil to delete file
    static func write(_ file: File, data: Data?) async throws {
        let fullURL = singleton.sharedFolder.appendingPathComponent(file.rawValue)
        try await singleton.write(at: fullURL, data: data)
    }

    static func write(_ url: URL, data: Data?) async throws {
        try await singleton.write(at: url, data: data)
    }

    
    /// Returns nil if file missing
    static func read(_ file: File) async throws -> Data? {
        let fullURL = singleton.sharedFolder.appendingPathComponent(file.rawValue)
        return try await singleton.read(at: fullURL)
    }
    
    static func read(_ url: URL) async throws -> Data? {
        try await singleton.read(at: url)
    }
    
    static func url(for file: File) -> URL {
        singleton.sharedFolder.appendingPathComponent(file.rawValue)
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
    
    private func read(at url: URL) async throws -> Data? {
        let fileName = url.lastPathComponent
        
        return try await withCheckedThrowingContinuation { continuation in
            Task(priority: .utility) {
                do {
                    print("👀 Reading \(fileName)")
                    let data = try Data(contentsOf: url)
                    continuation.resume(returning: data)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private var sharedFolder: URL {
        let appGroup = "group.com.dimdl.shared"
        guard let folder = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) else {
            fatalError("No shared folder - AppGroup misconfigured")
        }
        return folder
    }
}
