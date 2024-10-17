// Copyright © 2024 Zama. All rights reserved.

import TFHE

extension ServerKeyCompressed {
    func setServerKey() throws {
        let decompressed = try decompress()
        set_server_key(decompressed.pointer)
    }
    
    private func decompress() throws -> ServerKey {
        var serverKeyPointer: OpaquePointer? // ServerKey
        try wrap { compressed_server_key_decompress(self.pointer, &serverKeyPointer) }
        return ServerKey(pointer: serverKeyPointer)
    }
}
