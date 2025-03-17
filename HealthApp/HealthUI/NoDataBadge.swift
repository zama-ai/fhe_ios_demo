// Copyright © 2025 Zama. All rights reserved.

import SwiftUI

#Preview {
    NoDataBadge()
}

struct NoDataBadge: View {
    var body: some View {
        Text("No data found")
            .foregroundStyle(.secondary)
            .customFont(.callout)
            .fontWeight(.regular)
    }
}
