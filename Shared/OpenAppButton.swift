// Copyright © 2024 Zama. All rights reserved.

import SwiftUI
import StoreKit

#Preview {
    @Previewable @State var showAlert: Bool = false
    let uber = AppInfo(name: "Uber", scheme: "uber://", appStoreID: "123")
    
    Group {
        OpenAppButton(uber)
        
        OpenAppButton(uber) {
            Label("Uber", systemImage: "car.side.fill")
        }
    }
    .buttonStyle(.bordered)
    .environment(\.openURL, .init(handler: { url in
        print("opening \(url)…")
        return .discarded
    }))
}

struct AppInfo {
    let name: String
    let scheme: String
    let appStoreID: String
    
    static let appleHealth = AppInfo(name: "Apple Health", scheme: "x-apple-health://", appStoreID: "1242545199")
    static let fheDataVault = AppInfo(name: "FHE Data Vault", scheme: "fhedatavault://", appStoreID: "6738993762")
    static let fheHealth = AppInfo(name: "FHE Health", scheme: "fhehealthapp://", appStoreID: "6738993713")
    static let fheAdTargeting = AppInfo(name: "FHE Ad Targeting", scheme: "fheadsapp://", appStoreID: "6739003587")
}

struct OpenAppButton<Label: View>: View {
    let app: AppInfo
    let label: () -> Label

    @State private var showAlert = false
    @State private var showOverlay = false
    @Environment(\.openURL) private var openURL

    init(_ app: AppInfo, @ViewBuilder label: @escaping () -> Label) {
        self.app = app
        self.label = label
    }

    init(_ app: AppInfo) where Label == Text {
        self.app = app
        self.label = { Text("Open \(app.name)") }
    }
    
    var body: some View {
        Button {
            openURL(URL(string: app.scheme)!) { canOpen in
                if !canOpen {
                    showAlert = true
                }
            }
        } label: {
            label()
        }
        .alert("Install \(app.name)", isPresented: $showAlert) {
            Button("Cancel", role: .cancel) {}
            Button("App Store") {
                showOverlay = true
            }
        } message: {
            Text("Please install \(app.name) from the App Store.")
        }
        .appStoreOverlay(isPresented: $showOverlay) {
            SKOverlay.AppConfiguration(appIdentifier: app.appStoreID, position: .bottom)
        }
    }
}

