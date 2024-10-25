// Copyright © 2024 Zama. All rights reserved.

import Foundation

extension ClientView {
    @MainActor
    final class ViewModel: ObservableObject {
        @Published var sleepInput: Data?
        @Published var sleepResultQuality: Data?

        @Published var weightInput: Data?
        @Published var weightResultMin: Data?
        @Published var weightResultMax: Data?
        @Published var weightResultAvg: Data?

        func loadFromDisk() async throws {
            sleepInput = try await Storage.read(.sleepList)
            sleepResultQuality = try await Storage.read(.sleepScore)

            weightInput = try await Storage.read(.weightList)
            weightResultMin = try await Storage.read(.weightMin)
            weightResultMax = try await Storage.read(.weightMax)
            weightResultAvg = try await Storage.read(.weightAvg)
        }
        
        func getUserID() async throws -> String {
            guard let serverKey = try await Storage.read(.serverKey) else {
                throw NetworkingError.message("Server key missing")
            }

            if let uid = UserDefaults.standard.string(forKey: "uid") {
                return uid
            } else {
                let new = try await Network.shared.uploadServerKey(serverKey)
                UserDefaults.standard.set(new, forKey: "uid")
                return new
            }
        }

        func uploadSleep() async throws {
            guard let input = try await Storage.read(.sleepList) else {
                throw NetworkingError.message("Encrypted list missing")
            }

            let userID = try await getUserID()
            let quality = try await Network.shared.getSleepQuality(uid: userID, encryptedSleeps: input)
            
            try await Storage.write(.sleepScore, data: quality)
            sleepResultQuality = quality
        }

        func uploadWeight() async throws {
            guard let input = try await Storage.read(.weightList) else {
                throw NetworkingError.message("Encrypted list missing")
            }

            let userID = try await getUserID()
            let stats = try await Network.shared.getWeightStats(uid: userID, encryptedWeights: input)
            
            try await Storage.write(.weightMin, data: stats.min)
            try await Storage.write(.weightMax, data: stats.max)
            try await Storage.write(.weightAvg, data: stats.avg)
            
            weightResultMin = stats.min
            weightResultMax = stats.max
            weightResultAvg = stats.avg
        }
    }
}
