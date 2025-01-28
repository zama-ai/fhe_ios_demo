// Copyright © 2025 Zama. All rights reserved.

import Foundation
import TFHE

func wrap(_ fn: () -> Int32) throws {
    let result = fn()
    guard result == 0 else {
        throw FHEError.code(result)
    }
}

enum FHEError: LocalizedError {
    case code(Int32)
    case message(String)
    
    var errorDescription: String {
        switch self {
        case .code(let code): "TFHE Error: \(code)"
        case .message(let message): "TFHE Error: \(message)"
        }
    }
}

extension Data {
    func toDynamicBuffer() -> DynamicBuffer {
        let pointer = UnsafeMutablePointer<UInt8>.allocate(capacity: self.count)
        self.copyBytes(to: pointer, count: self.count)
        
        let buffer = DynamicBuffer(pointer: pointer, length: self.count, destructor: { pointer, length in
            pointer?.deallocate()
            return 0
        })
        
        return buffer
    }
}

extension DynamicBuffer {
    func toData() throws -> Data {
        guard let pointer = self.pointer else {
            throw FHEError.message("Empty DynamicBuffer")
        }
        
        let data = Data(bytes: pointer, count: self.length)
        
        if let destructor = self.destructor {
            let freeResult = destructor(pointer, self.length)
            if freeResult != 0 {
                print("Failed to free memory")
            }
        }
        
        return data
    }
}
