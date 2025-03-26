// Copyright © 2025 Zama. All rights reserved.

import CryptoKit
import Foundation

extension Data {
    /// Replacements for `Data.hashValue`, which is not designed for persistence or cryptographic use.
    var persistantHashValue: String {
        sha256Identifier
    }
    
    // Secure and stable across launches (Always produces the same output for the same input)
    private var sha256Identifier: String {
        let digest = SHA256.hash(data: self)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
