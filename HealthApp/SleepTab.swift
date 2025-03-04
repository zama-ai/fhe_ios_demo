// Copyright © 2025 Zama. All rights reserved.

import SwiftUI

#Preview {
    SleepTab()
}

struct SleepTab: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                OpenAppButton(.zamaDataVault(tab: .sleep)) {
                    Text("Import Encrypted Data")
                }

                AsyncButton("Select Encrypted Data") {
                    print("Show date picker")
                }

                CustomBox("Sleep Phase") {
                    Text("No data found")
                }
                
                CustomBox("Sleep Quality") {
                    Text("No data found")
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Sleep Analysis")
            .buttonStyle(.custom)
            .background(Color.zamaYellowLight)
        }
    }
}
