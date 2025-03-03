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
            
            let uid = try await getUserID(for: .sleep_quality)
            let taskID = try await Network.shared.startTask(.sleep_quality,
                                                            uid: uid,
                                                            encrypted_input: input)
            
            try await getResultForSleep(taskID: taskID, uid: uid)
        }
        
        func uploadWeight() async throws {
            guard let input = await Storage.read(.weightList) else {
                throw NetworkingError.message("Encrypted weight missing")
            }
            
            let uid = try await getUserID(for: .weight_stats)
            let taskID = try await Network.shared.startTask(.weight_stats,
                                                            uid: uid,
                                                            encrypted_input: input)
            
            try await getResultForWeight(taskID: taskID, uid: uid)
        }
                
        func getResultForWeight(taskID: String, uid: String) async throws {
            do {
                let tuple = try await Network.shared.getWeightResult(taskID: taskID, uid: uid)
                
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
        
        func getResultForSleep(taskID: String, uid: String) async throws {
            do {
                let quality = try await Network.shared.getSleepResult(taskID: taskID, uid: uid)
                try await Storage.write(.sleepScore, data: quality)
                sleepResultQuality = quality
            } catch let error as TaskError {
                print(error.localizedDescription)
            }
        }
    }
}
