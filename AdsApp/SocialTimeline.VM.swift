// Copyright © 2025 Zama. All rights reserved.

import Foundation

extension SocialTimeline {
    @MainActor
    final class ViewModel: ObservableObject {
        @Published var items: [TimelineItem]
        @Published var operationStatus: OperationStatus?
        @Published var dataVaultActionNeeded: Bool = false
        
        private let adFrequency = 2 // Show an ad every 3 posts
        private let adsLimit = 5 // Show top 5 ads
        
        var uid: String? {
            get { return UserDefaults.standard.string(forKey: "uid") }
            set { UserDefaults.standard.set(newValue, forKey: "uid") }
        }

        var taskID: String? {
            get { return UserDefaults.standard.string(forKey: "taskID") }
            set { UserDefaults.standard.set(newValue, forKey: "taskID") }
        }
        
        init() {
            self.items = Post.samples.map({ TimelineItem.post($0) })
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
            
            try await performActivity("Uploading ServerKey") {
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

            try await performActivity("Uploading Encrypted Profile") {
                let newTaskID = try await Network.shared.startTask(.ad_targeting, uid: uid, encrypted_input: profile)
                self.taskID = newTaskID
                try await startPolling(every: 3, taskID: newTaskID, uid: uid)
            }
        }
        
        func startPolling(every interval: TimeInterval, taskID: String, uid: String) async throws {
            while true {
                do {
                    if let data = try await getServerResult(taskID: taskID, uid: uid) {
                        print("✅ Data received: \(data)")
                        // Do something with Data
                        // Then return
                        return
                    }
                } catch {
                    print("🚨 Error encountered: \(error)")
                    throw error // Stop polling if getServerResult() throws
                }

                print("⏳ Waiting \(interval) seconds before retrying...")
                try await Task.sleep(for: .seconds(interval))
            }
        }
        
        func getServerResult(taskID: String, uid: String) async throws -> Data? {
            do {
                let result = try await Network.shared.getTaskResult(for: .ad_targeting, taskID: taskID, uid: uid)
                return result
                // for position in 0..<adsLimit {
                //     // We duplicate the result for each ad we want to display. Limitation of how QL works.
                //     try await Storage.write(.concreteEncryptedResult, data: result, suffix: "\(position)")
                // }

            } catch TaskError.needToWait {
                return nil
            } catch {
                throw error
            }
        }
        
        func performActivity(_ name: String, block: () async throws -> Void) async rethrows {
            self.operationStatus = .progress("\(name)…")
            do {
                try await block()
                self.operationStatus = nil
            } catch {
                self.operationStatus = .error(error.localizedDescription)
                throw error
            }
        }
        
//        private static let initialize: Void = {
//            Task {
//                print("SocialTimeline initialize: This runs only once for all instances.")
//                try await writeAdsResults()
//            }
//        }()

//        static func generateItems() -> [TimelineItem] {
//            var items: [TimelineItem] = []
//            var adIndex = 0
//
//            for (index, post) in Post.samples.enumerated() {
//                items.append(.post(post))
//                
//                 Insert an ad after every `adFrequency` posts
//                if (index + 1) % Self.adFrequency == 0, adIndex < Self.adsLimit {
//                    items.append(.ad(adIndex))
//                    adIndex += 1
//                }
//            }
//            return items
//        }
    }
}
