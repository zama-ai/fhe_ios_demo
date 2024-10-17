// Copyright © 2024 Zama. All rights reserved.

import Foundation
import TFHE

extension FHEUInt16Array {
    func readItems() throws -> [FHEUInt16] {
        if cachedItems.isEmpty {
            self.cachedItems = try expandItems()
        }
        return cachedItems
    }
    
    func stats() throws -> (min: FHEUInt16, max: FHEUInt16, avg: FHEUInt16) {
        let items = try readItems()
        assert(items.count != 0, "empty array, cannot find min/max")
        var min: FHEUInt16 = items[0]
        var max: FHEUInt16 = items[0]
        var sum: FHEUInt16 = items[0]
        
        for num in items[1...] {
            min = try min.min(with: num)
            max = try max.max(with: num)
            sum = try sum.addFHE(int: num) // TODO Optim: use fhe_uint16_sum()
        }
        
        let avg = try sum.divScalar(int: items.count)
        return(min, max, avg)
    }
    
    private func expandItems() throws -> [FHEUInt16] {
        var expander: OpaquePointer? // CompactCiphertextListExpander

        try wrap {
            compact_ciphertext_list_expand(pointer, &expander)
        }
        
        var length: Int = 0
        try wrap {
            compact_ciphertext_list_expander_len(expander, &length)
        }

        var array: [FHEUInt16] = []
        for int in 0..<length {
            var pointer: OpaquePointer? // FheUint16
            try wrap {
                // Ensure slot has correct type
                var type: FheTypes = Type_FheBool
                let ok = compact_ciphertext_list_expander_get_kind_of(expander, 0, &type);
                assert(type == Type_FheUint16);
                return ok
            }

            try wrap {
                compact_ciphertext_list_expander_get_fhe_uint16(expander, int, &pointer)
            }
            array.append(FHEUInt16(pointer: pointer))
        }
        
        compact_ciphertext_list_expander_destroy(expander)
        
        return array
    }    
}
