// Copyright © 2024 Zama. All rights reserved.

import Foundation

extension ClientView {
    @MainActor
    final class ViewModel: ObservableObject {
        @Published var encryptedWeight: Data?
        @Published var encryptedMin: Data?
        @Published var encryptedMax: Data?
        @Published var encryptedAvg: Data?
        @Published var encryptedSleep: Data?

        func loadFromDisk() async throws {
            encryptedWeight = try await Storage.read(.weightList)
            encryptedMin = try await Storage.read(.weightMin)
            encryptedMax = try await Storage.read(.weightMax)
            encryptedAvg = try await Storage.read(.weightAvg)
        }
        
        func upload() async throws {
            guard let serverKey = try await Storage.read(.serverKey) else {
                throw NetworkingError.message("Server key missing")
            }
            
            guard let array = try await Storage.read(.weightList) else {
                throw NetworkingError.message("Encrypted list missing")
            }

            let userID = try await Network.shared.uploadServerKey(serverKey)
            let stats = try await Network.shared.getStats(uid: userID, encryptedArray: array)
            
            try await Storage.write(.weightMin, data: stats.min)
            try await Storage.write(.weightMax, data: stats.max)
            try await Storage.write(.weightAvg, data: stats.avg)
            
            encryptedMin = stats.min
            encryptedMax = stats.max
            encryptedAvg = stats.avg
        }
    }
}
