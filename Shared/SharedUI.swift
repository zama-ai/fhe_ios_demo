// Copyright © 2025 Zama. All rights reserved.

import SwiftUI

struct ZamaLink: View {
    var body: some View {
        Link(destination: ZamaBrand.website) {
            Image(.logoZamaZblack)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 32, height: 32)
                .opacity(0.095)
                .padding(.trailing, 16)
                .padding(.top, -4)
        }
    }
}
