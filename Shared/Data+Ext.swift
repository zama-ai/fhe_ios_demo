// Copyright © 2024 Zama. All rights reserved.

import Foundation

extension Data {
    func snippet(first: Int) -> String {
        self.prefix(first)
            .map { String(format: "%02x", $0) }
            .joined()
    }
    
    var formattedSize: String {
        self.count.formatted(.byteCount(style: .file))
    }
}
