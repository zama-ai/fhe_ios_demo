// Copyright © 2025 Zama. All rights reserved.

import SwiftUI
struct PreviewContent: View {
    @ObservedObject var viewModel: ViewModel
    
    var body: some View {
        if let ad = viewModel.ad {
            AdView(ad: ad)
        } else {
            Text("No Ad OMG")
        }
    }
}

final class ViewModel: ObservableObject {
    @Published var ad: AdModel?
    
    init(ad: AdModel? = nil) {
        self.ad = ad
    }
}
