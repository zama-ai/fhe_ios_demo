// Copyright © 2025 Zama. All rights reserved.

import SwiftUI

#Preview {
    WeightTab()
}

struct WeightTab: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
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
            .background(.zamaBackgroundPage)
        }
    }
}
