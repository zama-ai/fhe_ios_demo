// Copyright © 2024 Zama. All rights reserved.

import Foundation

extension Data {
    static var random: Data {
        UUID().uuidString.data(using: .utf8) ?? Data(repeating: 42, count: 42)
    }
    
    func snippet(first: Int) -> String {
        self.prefix(first)
            .map { String(format: "%02x", $0) }
            .joined()
    }
    
    var formattedSize: String {
        self.count.formatted(.byteCount(style: .file))
    }
}
