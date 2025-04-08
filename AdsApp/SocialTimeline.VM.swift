// Copyright © 2025 Zama. All rights reserved.

import Foundation

extension SocialTimeline {
    @MainActor
    final class ViewModel: ObservableObject {
        @Published var items: [TimelineItem]
        @Published var activityReport: ActivityReport?
        @Published var dataVaultActionNeeded: Bool = false
        
        static private let adFrequency = 2 // Show an ad every 3 posts
        static private let adsLimit = 5 // Show top 5 ads
        
        @UserDefaultsStorage(key: "v12.uid", defaultValue: nil)
        private var uid: String?
        
        @UserDefaultsStorage(key: "v12.taskID", defaultValue: nil)
        private var taskID: String?
        
        @UserDefaultsStorage(key: "v12.profileHash", defaultValue: nil)
        static private var profileHash: String?
        
        init() {
            self.items = Self.generateItems(profileHash: Self.profileHash, resultsReadyOnDisk: false)
        }
        
        func refreshFromDisk() {
            Task {
                do {
                    dataVaultActionNeeded = false
                    try await startServerKeyUpload()
                } catch CustomError.missingServerKey, CustomError.missingProfile {
                    dataVaultActionNeeded = true
                } catch {
                    print(error.localizedDescription)
                }
            }
        }
        
        private func startServerKeyUpload() async throws {
            if let uid {
                try await startProfileUpload(uid: uid)
                return
            }
            
            guard let sk = await Storage.read(.concreteCPUCompressionKey) else {
                throw CustomError.missingServerKey
            }
            
            try await reportActivity("Uploading ServerKey") {
                let newUID = try await Network.shared.uploadServerKey(sk, for: .ad_targeting)
                self.uid = newUID
                try await startProfileUpload(uid: newUID)
            }
        }
        
        private func startProfileUpload(uid: String) async throws {
            guard let profile = await Storage.read(.concreteEncryptedProfile) else {
                throw CustomError.missingServerKey
            }
            
            let profileHash = profile.stableHashValue
            guard profileHash != Self.profileHash else {
                print("Profile unchanged, skipping upload")
                self.items = Self.generateItems(profileHash: profileHash, resultsReadyOnDisk: true)
                return
            }
            
            try await reportActivity("Uploading Encrypted Profile") {
                let newTaskID = try await Network.shared.startTask(.ad_targeting, uid: uid, encrypted_input: profile)
                self.taskID = newTaskID
                try await getServerResult(taskID: newTaskID, uid: uid, profileHash: profileHash)
            }
        }
        
        private func getServerResult(taskID: String, uid: String, profileHash: String) async throws {
            let result = try await Network.shared.getAdTargetingResult(taskID: taskID, uid: uid)
            for position in 0..<Self.adsLimit {
                // Duplicating result for each ad to display. Limitation of how QL works.
                try await Storage.write(.concreteEncryptedResult, data: result, suffix: "\(profileHash)-\(position)")
                Self.profileHash = profileHash
            }
            self.taskID = nil
            self.items = Self.generateItems(profileHash: profileHash, resultsReadyOnDisk: true)
        }
        
        private func reportActivity(_ name: String, block: () async throws -> Void) async rethrows {
            self.activityReport = .progress("\(name)…")
            do {
                try await block()
                self.activityReport = nil
            } catch {
                self.activityReport = .error(error.localizedDescription)
                throw error
            }
        }
        
        static private func generateItems(profileHash: String?, resultsReadyOnDisk: Bool) -> [TimelineItem] {
            var items: [TimelineItem] = []
            var adIndex = 0
            
            for (index, post) in Post.samples.enumerated() {
                items.append(.post(post))
                
                // Insert an ad after every `adFrequency` posts
                if let profileHash, resultsReadyOnDisk, (index + 1) % Self.adFrequency == 0, adIndex < Self.adsLimit {
                    items.append(.ad(position: adIndex, profileHash: profileHash))
                    adIndex += 1
                }
            }
            return items
        }
    }
}
