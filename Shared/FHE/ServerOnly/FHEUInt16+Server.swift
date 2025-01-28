// Copyright © 2025 Zama. All rights reserved.

import TFHE

extension FHEUInt16 {
    // MARK: - COMPUTE (needs set_server_key() called) -
    func addScalar(int: Int) throws -> FHEUInt16 {
        var result: OpaquePointer? // FheUint16
        try wrap { fhe_uint16_scalar_add(pointer, UInt16(int), &result) }
        return FHEUInt16(pointer: result)
    }
    
    func addFHE(int: FHEUInt16) throws -> FHEUInt16 {
        var result: OpaquePointer? // FheUint16
        try wrap { fhe_uint16_add(pointer, int.pointer, &result) }
        return FHEUInt16(pointer: result)
    }
    
    /// Warning: result is necessarily clipped (Int not Float)
    func divScalar(int: Int) throws -> FHEUInt16 {
        var result: OpaquePointer? // FheUint16
        try wrap { fhe_uint16_scalar_div(pointer, UInt16(int), &result) }
        return FHEUInt16(pointer: result)
    }
    
    func max(with int: FHEUInt16) throws -> FHEUInt16 {
        var result: OpaquePointer? // FheUint16
        try wrap { fhe_uint16_max(self.pointer, int.pointer, &result) }
        return FHEUInt16(pointer: result)
    }
    
    func min(with int: FHEUInt16) throws -> FHEUInt16 {
        var result: OpaquePointer? // FheUint16
        try wrap { fhe_uint16_min(self.pointer, int.pointer, &result) }
        return FHEUInt16(pointer: result)
    }
}
