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

        // Whether this file should be shared with other apps via AppGroup, or stay private to current app (+ extensions)
        enum Confidentiality {
            case groupShared(groupID: String)
            case privateToAppAndExtensions(groupID: String)
        }
        
        var confidentiality: Confidentiality {
            switch self {
            case .clientKey:
                    .privateToAppAndExtensions(groupID: "group.ai.zama.fhedemo.healthPrivate")
                
            case .concretePrivateKey:
                    .privateToAppAndExtensions(groupID: "group.ai.zama.fhedemo.adsPrivate")
                
            case .sleepList, .sleepScore,
                    .weightList, .weightMin, .weightMax, .weightAvg,
                    .publicKey, .serverKey,
                    .concreteCPUCompressionKey, .concreteEncryptedProfile, .concreteEncryptedResult:
                    .groupShared(groupID: "group.ai.zama.fhedemo.shared")
            }
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
        let folders = [
            "Shared Folder": fileManager.containerURL(forSecurityApplicationGroupIdentifier: "group.ai.zama.fhedemo.shared"),
            "Private Folder (Health)": fileManager.containerURL(forSecurityApplicationGroupIdentifier: "group.ai.zama.fhedemo.healthPrivate"),
            "Private Folder (Ads)": fileManager.containerURL(forSecurityApplicationGroupIdentifier: "group.ai.zama.fhedemo.adsPrivate")
        ].compactMapValues({ $0?.appending(component: "v12") })
        
        do {
            for folder in folders {
                print("🗂️ \(folder.key): \nopen \(folder.value)")
                if !fileManager.fileExists(atPath: folder.value.path) {
                    try fileManager.createDirectory(at: folder.value, withIntermediateDirectories: true, attributes: nil)
                }
            }
        } catch {
            print(error)
        }
    }
    
    private static let singleton = Storage()
    private let fileManager = FileManager.default
    
    /// Pass nil to delete file
    static func write(_ file: File, data: Data?, suffix: String? = nil) async throws {
        let fileName = file.withSuffix(suffix)
        let fullURL = singleton.destinationFolder(for: file).appendingPathComponent(fileName)
        try await singleton.write(at: fullURL, data: data)
    }
    
    static func write(_ url: URL, data: Data?) async throws {
        try await singleton.write(at: url, data: data)
    }
    
    static func deleteFromDisk(_ file: Storage.File, suffix: String? = nil) async throws {
        try await Storage.write(file, data: nil, suffix: suffix)
    }
    
    /// Returns nil if file missing
    static func read(_ file: File) async -> Data? {
        let fullURL = singleton.destinationFolder(for: file).appendingPathComponent(file.rawValue)
        return await singleton.read(at: fullURL)
    }
    
    static func read(_ url: URL) async -> Data? {
        await singleton.read(at: url)
    }
    
    static func url(for file: File, suffix: String? = nil) -> URL {
        let fileName = file.withSuffix(suffix)
        return singleton.destinationFolder(for: file).appendingPathComponent(fileName)
    }
    
    static func listEncryptedFiles(matching file: File) throws -> [URL] {
        let folder = singleton.destinationFolder(for: file)
        let fileURLs = try singleton.fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
        
        let pattern = file.rawValue.components(separatedBy: ".")
        let result = fileURLs.filter {
            $0.pathExtension == pattern.last
            && !$0.deletingPathExtension().lastPathComponent.hasSuffix("-preview")
            && $0.lastPathComponent.hasPrefix(pattern.first!)
        }
        
        return result
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
            try fileManager.removeItem(at: url)
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
    
    private func destinationFolder(for file: File) -> URL {
        switch file.confidentiality {
        case .privateToAppAndExtensions(let groupID),
                .groupShared(groupID: let groupID):
            return scopedFolder(for: groupID)
        }
    }
    
    private func scopedFolder(for groupID: String) -> URL {
        guard let sharedFolder = fileManager.containerURL(forSecurityApplicationGroupIdentifier: groupID) else {
            fatalError("No shared folder - AppGroup misconfigured")
        }
        return sharedFolder.appending(component: "v12")
    }
}

extension Data {
    var formattedSize: String {
        self.count.formatted(.byteCount(style: .file))
    }
}

extension Storage {
    // MARK: - Date (eg, for nights) -
    //
    static func suffix(for date: Date) -> String {
        date.formatted(date: .numeric, time: .omitted)
            .replacingOccurrences(of: "/", with: "-")
    }
    
    // Ex: sleepList-23-03-2025.fheencrypted
    static func date(from fileName: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MM-yyyy"
        formatter.locale = Locale(identifier: "en_US_POSIX") // Ensures consistent parsing
        
        let text = fileName
            .replacingOccurrences(of: "sleepList-", with: "")
            .replacingOccurrences(of: ".fheencrypted", with: "")
        
        return formatter.date(from: text)
    }
    
    // MARK: - DateInterval (eg, for weights) -
    
    static func suffix(for interval: DateInterval) -> String {
        let start = interval.start
            .formatted(date: .numeric, time: .omitted)
            .replacingOccurrences(of: "/", with: "-")
        
        let end = interval.end
            .formatted(date: .numeric, time: .omitted)
            .replacingOccurrences(of: "/", with: "-")
        
        return "\(start)_\(end)"
    }
    
    // Ex: weightList-25-09-2024_25-03-2025.fheencrypted
    static func dateInterval(from fileName: String) -> DateInterval? {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MM-yyyy"
        formatter.locale = Locale(identifier: "en_US_POSIX") // Ensures consistent parsing
        
        let comps = fileName
            .replacingOccurrences(of: "weightList-", with: "")
            .replacingOccurrences(of: ".fheencrypted", with: "")
            .components(separatedBy: "_")
        
        if comps.count == 2,
           let a = comps.first,
           let b = comps.last,
           let start = formatter.date(from: a),
           let end = formatter.date(from: b) {
            return DateInterval(start: start, end: end)
        }
        
        return nil
    }
}
