// Copyright © 2025 Zama. All rights reserved.

import Foundation

extension Data {
    /// Returns a string containing the first `N` bytes of the data's string representation.
    func snippet(first: Int) -> String {
        self.prefix(first)
            .map { String(format: "%02x ", $0) }
            .joined()
    }
}
