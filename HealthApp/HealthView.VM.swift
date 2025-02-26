// Copyright © 2025 Zama. All rights reserved.

import Foundation

extension HealthView {
    @MainActor
    final class ViewModel: ObservableObject {
        @Published var sleepInput: Data?
        @Published var sleepResultQuality: Data?
        
        @Published var weightInput: Data?
        @Published var weightResultMin: Data?
        @Published var weightResultMax: Data?
        @Published var weightResultAvg: Data?
                
        func loadFromDisk() async throws {
            sleepInput = await Storage.read(.sleepList)
            sleepResultQuality = await Storage.read(.sleepScore)
            
            weightInput = await Storage.read(.weightList)
            weightResultMin = await Storage.read(.weightMin)
            weightResultMax = await Storage.read(.weightMax)
            weightResultAvg = await Storage.read(.weightAvg)
        }
        
        func getUserID(for task: Network.ServerTask) async throws -> String {
            guard let serverKey = await Storage.read(.serverKey) else {
                throw NetworkingError.message("Server key missing")
            }
            
            if let uid = UserDefaults.standard.string(forKey: "uid") {
                return uid
            } else {
                let new = try await Network.shared.uploadServerKey(serverKey, for: task)
                UserDefaults.standard.set(new, forKey: "uid")
                return new
            }
        }
        
        func uploadSleep() async throws {
            guard let input = await Storage.read(.sleepList) else {
                throw NetworkingError.message("Encrypted sleep missing")
            }
            
            let userID = try await getUserID(for: .sleep_quality)
            let taskID = try await Network.shared.startTask(.sleep_quality,
                                                            uid: userID,
                                                            encrypted_input: input)
            
            UserDefaults.standard.set(taskID, forKey: Self.sleepTaskIDKey)
        }
        
        func uploadWeight() async throws {
            guard let input = await Storage.read(.weightList) else {
                throw NetworkingError.message("Encrypted weight missing")
            }
            
            let userID = try await getUserID(for: .weight_stats)
            let taskID = try await Network.shared.startTask(.weight_stats,
                                                            uid: userID,
                                                            encrypted_input: input)
            
            UserDefaults.standard.set(taskID, forKey: Self.weightTaskIDKey)
        }
        
        func checkStatus(for task: Network.ServerTask) async throws {
            guard let taskID = taskID(for: task) else { return }
            let userID = try await getUserID(for: task)
            let _ = try await Network.shared.getStatus(for: task, id: taskID, uid: userID)
        }
        
        func getResultForWeight() async throws {
            let task: Network.ServerTask = .weight_stats
            let userID = try await getUserID(for: task)
            guard let taskID = taskID(for: task) else {
                return
            }

            do {
                let tuple = try await Network.shared.getWeightResult(taskID: taskID, uid: userID)
                
                try await Storage.write(.weightMin, data: tuple.min)
                try await Storage.write(.weightMax, data: tuple.max)
                try await Storage.write(.weightAvg, data: tuple.avg)
                
                weightResultMin = tuple.min
                weightResultMax = tuple.max
                weightResultAvg = tuple.avg

            } catch let error as TaskError {
                print(error.localizedDescription)
            }
        }
        
        func getResultForSleep() async throws {
            let task: Network.ServerTask = .sleep_quality
            let userID = try await getUserID(for: task)
            guard let taskID = taskID(for: task) else {
                return
            }

            do {
                let quality = try await Network.shared.getTaskResult(for: .sleep_quality, taskID: taskID, uid: userID)
                try await Storage.write(.sleepScore, data: quality)
                sleepResultQuality = quality
            } catch let error as TaskError {
                print(error.localizedDescription)
            }
        }
        
        private func taskID(for task: Network.ServerTask) -> String? {
            let key = switch task {
            case .weight_stats: Self.weightTaskIDKey
            case .sleep_quality: Self.sleepTaskIDKey
            case .ad_targeting: Self.adsTaskIDKey
            }
            return UserDefaults.standard.string(forKey: key)
        }
        
        static let weightTaskIDKey = "taskID.weightStats"
        static let sleepTaskIDKey = "taskID.sleepQuality"
        static let adsTaskIDKey = "taskID.adsTargeting"
    }
}
