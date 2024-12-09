// Copyright © 2024 Zama. All rights reserved.

import SwiftUI

#Preview {
    @Previewable @State var showAlert: Bool = false
    let uber = OpenOtherAppButton.App.init(name: "Uber", scheme: "uber://", appStoreID: "nil")
    OpenOtherAppButton(app: uber, showAlert: $showAlert)
}

struct OpenOtherAppButton: View {
    struct App {
        let name: String
        let scheme: String
        let appStoreID: String?
        
        static let appleHealth = App(name: "Apple Health", scheme: "x-apple-health://", appStoreID: nil)
        static let fheDataVault = App(name: "FHE Data Vault", scheme: "fhedatavault://", appStoreID: nil)
        static let fheHealth = App(name: "FHE Health", scheme: "fhehealthapp://", appStoreID: nil)
        static let fheAdTargeting = App(name: "FHE Ad Targeting", scheme: "fheadsapp://", appStoreID: nil)
    }
    
    let app: App
    @Binding var showAlert: Bool
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        Button("Open \(app.name)") {
            openURL(URL(string: app.scheme)!) { canOpen in
                if !canOpen {
                    showAlert = true
                }
            }
        }
        .alert("Install \(app.name)", isPresented: $showAlert) {
            Button("Cancel") {}
            Button("App Store", role: .cancel) {
                openURL(URL(string: "itms-apps://itunes.apple.com/")!)
            }
        } message: {
            Text("Please install \(app.name) from the App Store.")
        }
    }
}

