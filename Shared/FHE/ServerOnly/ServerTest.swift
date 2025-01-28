// Copyright © 2025 Zama. All rights reserved.

import Foundation
import TFHE

func serverTest() async throws {
    for file in Storage.File.allCases {
        try? await Storage.deleteFromDisk(file)
    }
    
    let ck = try ClientKey.generate()
    let pk = try PublicKeyCompact(clientKey: ck)
    let sk = try ServerKeyCompressed(clientKey: ck)
    let inputInt = try FHEUInt16(encrypting: 42, clientKey: ck)
    
    let array: [Double] = [72, 71, 69, 71, 70, 73, 65.3]
    let coeff: Int = precisionCoeff(for: 1)
    let bigArray = array.map { Int($0 * Double(coeff)) }
    let inputArray = try FHEUInt16Array(encrypting: bigArray, publicKey: pk)
    
    try await ck.writeToDisk(.clientKey)
    try await pk.writeToDisk(.publicKey)
    try await sk.writeToDisk(.serverKey)
    
    try await inputArray.writeToDisk(.weightList)
    
    let time = Date()
    guard let ck2 = try await ClientKey.readFromDisk(.clientKey),
          let sk2 = try await ServerKeyCompressed.readFromDisk(.serverKey),
          let _ = try await PublicKeyCompact.readFromDisk(.publicKey),
          let inputArray2 = try await FHEUInt16Array.readFromDisk(.weightList) else {
        assert(true, "Data not on disk")
        return
    }
    
    // On Server
    try sk2.setServerKey()
    let resultStats = try inputArray2.stats()
    let time2 = Date()
    
    try await resultStats.min.writeToDisk(.weightMin)
    try await resultStats.max.writeToDisk(.weightMax)
    try await resultStats.avg.writeToDisk(.weightAvg)
    // End Server
    
    
    let min = try resultStats.min.decrypt(clientKey: ck) / coeff
    let max = try resultStats.max.decrypt(clientKey: ck) / coeff
    let rawAvg = try resultStats.avg.decrypt(clientKey: ck)
    let avg = Double(rawAvg) / Double(coeff)
    
    print("Results are: min: \(min), max: \(max), avg: \(avg)")
    print("Time taken: \(time2.timeIntervalSince(time).formatted(.number.precision(.fractionLength(2)))) seconds")
}

// 0 => 1
// 1 => 10
// 2 => 100
private func precisionCoeff(for decimalPrecision: Int) -> Int {
    Int(pow(10.0, Double(decimalPrecision)))
}
