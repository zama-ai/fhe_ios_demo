// Copyright © 2025 Zama. All rights reserved.

import SwiftUI
struct PreviewContent: View {
    @ObservedObject var viewModel: ViewModel
    
    var body: some View {
        if let ad = ViewModel.allAds.first(where: { $0.id == viewModel.adID }) {
            AdView(ad: ad)
        } else {
            Text("No Ad OMG")
        }
    }
}

final class ViewModel: ObservableObject {
    static let allAds: [AdModel] = {
        do {
            print("Load JSON. This runs only once for all instances.")
            
            if let url = Bundle.main.url(forResource: "allAds", withExtension: "json"),
               let data = FileManager.default.contents(atPath: url.path) {
                return try AdModel.allAds(from: data)
            }
        } catch {
            print("Decoding error: \(error)")
        }
        return []
    }()
    
    @Published var adID: Int?
    
    init(adID: Int? = nil) {
        self.adID = adID
    }
}
