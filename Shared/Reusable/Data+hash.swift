// Copyright © 2025 Zama. All rights reserved.

import CryptoKit
import Foundation

extension Data {
    var md5Identifier: String {
        let digest = Insecure.MD5.hash(data: self)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

extension Data {
    var sha256Identifier: String {
        let digest = SHA256.hash(data: self)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
