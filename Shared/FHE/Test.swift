// Copyright © 2024 Zama. All rights reserved.

import Foundation
import TFHE

func fheTest() async throws {
    for persistable in [ClientKey.self, CompressedServerKey.self, FHEUInt16.self] as [Persistable.Type] {
        try? await persistable.deleteFromDisk()
    }
    
    let ck = try ClientKey.generate()
    let sk = try CompressedServerKey(clientKey: ck)
    let input = try FHEUInt16(encrypting: 8, clientKey: ck)
    
    try await ck.writeToDisk()
    try await sk.writeToDisk()
    try await input.writeToDisk()
    
    guard let ck2 = try await ClientKey.readFromDisk(),
          let sk2 = try await CompressedServerKey.readFromDisk(),
          let input2 = try await FHEUInt16.readFromDisk() else {
        assert(true, "Data not on disk")
        return
    }
    
    // On Server
    try sk2.setServerKey()
    let result = try input2.addScalar(int: 30)
    try await result.writeToDisk()
    //
    
    guard let result2 = try await FHEUInt16.readFromDisk() else {
        assert(true, "Result not on disk")
        return
    }
    
    let clear = try result2.decrypt(clientKey: ck2)
    print("Result is", clear)
}
