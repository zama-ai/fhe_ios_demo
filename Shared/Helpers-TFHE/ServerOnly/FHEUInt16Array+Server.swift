// Copyright © 2025 Zama. All rights reserved.

import TFHE

extension FHEUInt16Array {
    func stats() throws -> (min: FHEUInt16, max: FHEUInt16, avg: FHEUInt16) {
        let items = try readItems()
        assert(items.count != 0, "empty array, cannot find min/max/avg")
        var min: FHEUInt16 = items[0]
        var max: FHEUInt16 = items[0]
        var sum: FHEUInt16 = items[0]
        
        for num in items[1...] {
            min = try min.min(with: num)
            max = try max.max(with: num)
            sum = try sum.addFHE(int: num) // TODO Optim: use fhe_uint16_sum()
        }
        
        let avg = try sum.divScalar(int: items.count)
        return (min, max, avg)
    }
}
