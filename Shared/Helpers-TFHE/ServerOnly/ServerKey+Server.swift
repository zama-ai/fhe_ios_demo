// Copyright © 2025 Zama. All rights reserved.

import TFHE

extension ServerKeyCompressed {
    func setServerKey() throws {
        var serverKeyPointer: OpaquePointer? // ServerKey
        try wrap { compressed_server_key_decompress(self.pointer, &serverKeyPointer) }
        set_server_key(serverKeyPointer)
    }
}
