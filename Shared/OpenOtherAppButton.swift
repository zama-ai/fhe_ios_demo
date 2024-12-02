// Copyright © 2024 Zama. All rights reserved.

import SwiftUI

#Preview {
    @Previewable @State var showAlert: Bool = false
    OpenOtherAppButton(appName: "Uber",
                       appScheme: "uber://",
                       appID: "1234",
                       showAlert: $showAlert)
}

struct OpenOtherAppButton: View {
    let appName: String
    let appScheme: String
    let appID: String?
    
    @Binding var showAlert: Bool
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button("View in \(appName)") {
            openURL(URL(string: appScheme)!) { canOpen in
                if !canOpen {
                    showAlert = true
                }
            }
        }
        .alert("Install \(appName)", isPresented: $showAlert) {
            Button("Cancel") {}
            Button("App Store", role: .cancel) {
                openURL(URL(string: "itms-apps://itunes.apple.com/")!)
            }
        } message: {
            Text("Please install \(appName) from the App Store.")
        }
    }
}

