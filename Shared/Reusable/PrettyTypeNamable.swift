// Copyright © 2025 Zama. All rights reserved.

protocol PrettyTypeNamable {}
extension PrettyTypeNamable {
    var prettyTypeName: String {
        String(describing: self)
            .replacingOccurrences(of: "_", with: " ")
            .localizedCapitalized
    }
}
