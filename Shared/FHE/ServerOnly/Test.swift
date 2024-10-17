// Copyright © 2024 Zama. All rights reserved.

import Foundation
import TFHE

func fheTest() async throws {
    let types: [Persistable.Type] = [
        ClientKey.self,
        PublicKeyCompact.self,
        ServerKeyCompressed.self,
        FHEUInt16.self,
        FHEUInt16Array.self
    ]
    for persistable in types {
        try? await persistable.deleteFromDisk()
    }
    
    let ck = try ClientKey.generate()
    let pk = try PublicKeyCompact(clientKey: ck)
    let sk = try ServerKeyCompressed(clientKey: ck)
    let inputInt = try FHEUInt16(encrypting: 42, clientKey: ck)
    
    let array = [18, 22, 3, 4, 5, 6, 7, 8]
    let coeff = precisionCoeff(for: 1)
    let bigArray = array.map { $0 * coeff }
    let inputArray = try FHEUInt16Array(encrypting: bigArray, publicKey: pk)
    
    try await ck.writeToDisk()
    try await pk.writeToDisk()
    try await sk.writeToDisk()
    try await inputInt.writeToDisk()
    try await inputArray.writeToDisk()

    guard let ck2 = try await ClientKey.readFromDisk(),
          let sk2 = try await ServerKeyCompressed.readFromDisk(),
          let _ = try await PublicKeyCompact.readFromDisk(),
          let inputInt2 = try await FHEUInt16.readFromDisk(),
          let inputArray2 = try await FHEUInt16Array.readFromDisk() else {
        assert(true, "Data not on disk")
        return
    }
    
    // On Server
    try sk2.setServerKey()
    let resultInt = try inputInt2.addScalar(int: 42)
    let stats = try inputArray2.stats()
    
    try await resultInt.writeToDisk()
    // End Server
    

    guard let resultInt2 = try await FHEUInt16.readFromDisk() else {
        assert(true, "Result not on disk")
        return
    }
    
    let int = try resultInt2.decrypt(clientKey: ck2)
    let min = try stats.min.decrypt(clientKey: ck) / coeff
    let max = try stats.max.decrypt(clientKey: ck) / coeff
    let rawAvg = try stats.avg.decrypt(clientKey: ck)
    let avg = Double(rawAvg) / Double(coeff)
    print()

    print("Results are: int: \(int), min: \(min), max: \(max), avg: \(avg)")
}

// 0 => 1
// 1 => 10
// 2 => 100
private func precisionCoeff(for decimalPrecision: Int) -> Int {
    Int(pow(10.0, Double(decimalPrecision)))
}
