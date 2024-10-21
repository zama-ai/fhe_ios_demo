// Copyright © 2024 Zama. All rights reserved.

import Foundation

extension ClientView {
    @MainActor
    final class ViewModel: ObservableObject {
        @Published var encryptedWeight: Data?
        @Published var encryptedSleep: Data?

        func loadFromDisk() async throws {
            encryptedWeight = try await Storage.read(.weightList)
        }
        
        func upload() async throws {
            guard let serverKey = try await Storage.read(.serverKey) else {
                throw NetworkingError.message("Server key missing")
            }
            
            guard let array = try await Storage.read(.ageIn) else {
                throw NetworkingError.message("Encrypted list missing")
            }

            let userID = try await Network.shared.uploadServerKey(serverKey)
            let stats = try await Network.shared.getStats(uid: userID, encryptedArray: array)
            
            let min = try FHERenderable(.uint16, data: { stats.min })
            try await min.writeToDisk(.weightMin)

            let max = try FHERenderable(.uint16, data: { stats.max })
            try await max.writeToDisk(.weightMax)

            let avg = try FHERenderable(.uint16, data: { stats.avg })
            try await avg.writeToDisk(.weightAvg)
        }
    }
}
