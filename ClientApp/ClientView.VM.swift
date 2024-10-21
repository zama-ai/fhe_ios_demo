// Copyright © 2024 Zama. All rights reserved.

import Foundation

extension ClientView {
    @MainActor
    final class ViewModel: ObservableObject {
        @Published var encryptedWeight: Data?
        @Published var encryptedSleep: Data?

        func loadFromDisk() async throws {
            encryptedWeight = Data()//try await Storage.read(.encryptedInputList)
        }
        
        func upload() async throws {
            guard let serverKey = try await Storage.read(.serverKey) else {
                throw NetworkingError.message("Server key missing")
            }
            
            guard let array = try await Storage.read(.encryptedInputList) else {
                throw NetworkingError.message("Encrypted list missing")
            }

            let userID = try await Network.shared.uploadServerKey(serverKey)
            let stats = try await Network.shared.getStats(uid: userID, encryptedArray: array)
            
            try await Storage.write(.encryptedOutputMin, data: stats.min)
            try await Storage.write(.encryptedOutputMax, data: stats.max)
            try await Storage.write(.encryptedOutputAvg, data: stats.avg)
        }
    }
}
