// Copyright © 2025 Zama. All rights reserved.

import SwiftUI

#Preview {
    WeightTab()
}

struct WeightTab: View {
    @StateObject var vm: ViewModel = .fake
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                OpenAppButton(.zamaDataVault(tab: .weight)) {
                    Text("Import Encrypted Data")
                }

                AsyncButton("Select Encrypted Data") {
                    print("Show date picker")
                }

                CustomBox("Trend") {
                    Text("No data found")
                }
                
                CustomBox("Statistics") {
                    Text("No data found")
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Weight Analysis")
            .buttonStyle(.custom)
            .background(Color.zamaYellowLight)
        }
    }
}

extension WeightTab {
    @MainActor final class ViewModel: ObservableObject {
        @Published var selectedDates: Date?
        @Published var isProcessing: Bool
        
        static let fake = ViewModel(selectedDates: nil, isProcessing: false)
        
        init(selectedDates: Date?, isProcessing: Bool) {
            self.selectedDates = selectedDates
            self.isProcessing = isProcessing
        }
    }
}
