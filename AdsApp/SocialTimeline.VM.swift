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
        
        var uid: String? {
            get { return UserDefaults.standard.string(forKey: "uid") }
            set { UserDefaults.standard.set(newValue, forKey: "uid") }
        }

        var taskID: String? {
            get { return UserDefaults.standard.string(forKey: "taskID") }
            set { UserDefaults.standard.set(newValue, forKey: "taskID") }
        }

        var adsFetched: Bool? {
            get { return UserDefaults.standard.bool(forKey: "adsFetched") }
            set { UserDefaults.standard.set(newValue, forKey: "adsFetched") }
        }

        init() {
            self.items = Self.generateItems(includeAds: false) // TODO: unless ads already on disk ? 
        }

        @Sendable
        func onAppear() async {
            do {
                try await startServerKeyUpload()
            } catch CustomError.missingServerKey, CustomError.missingProfile {
                dataVaultActionNeeded = true
            } catch {
                print(error.localizedDescription)
            }
        }
        
        func startServerKeyUpload() async throws {
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
        
        // TODO: profile uploaded every time ?
        func startProfileUpload(uid: String) async throws {
            guard let profile = await Storage.read(.concreteEncryptedProfile) else {
                throw CustomError.missingServerKey
            }

            try await reportActivity("Uploading Encrypted Profile") {
                let newTaskID = try await Network.shared.startTask(.ad_targeting, uid: uid, encrypted_input: profile)
                self.taskID = newTaskID
                try await getServerResult(taskID: newTaskID, uid: uid)
            }
        }
                
        func getServerResult(taskID: String, uid: String) async throws {
            let result = try await Network.shared.getAdTargetingResult(taskID: taskID, uid: uid)
            for position in 0..<Self.adsLimit {
                // We duplicate the result for each ad we want to display. Limitation of how QL works.
                try await Storage.write(.concreteEncryptedResult, data: result, suffix: "\(position)")
            }
            self.taskID = nil
            self.adsFetched = true
            self.items = Self.generateItems(includeAds: true)
        }
        
        func reportActivity(_ name: String, block: () async throws -> Void) async rethrows {
            self.activityReport = .progress("\(name)…")
            do {
                try await block()
                self.activityReport = nil
            } catch {
                self.activityReport = .error(error.localizedDescription)
                throw error
            }
        }
        
        static func generateItems(includeAds: Bool) -> [TimelineItem] {
            var items: [TimelineItem] = []
            var adIndex = 0

            for (index, post) in Post.samples.enumerated() {
                items.append(.post(post))
                
                // Insert an ad after every `adFrequency` posts
                if includeAds, (index + 1) % Self.adFrequency == 0, adIndex < Self.adsLimit {
                    items.append(.ad(adIndex))
                    adIndex += 1
                }
            }
            return items
        }
    }
}
