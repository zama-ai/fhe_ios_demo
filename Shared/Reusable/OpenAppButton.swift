// Copyright © 2025 Zama. All rights reserved.

import SwiftUI
import StoreKit

#Preview {
    let app = AppInfo(name: "Uber", deeplink: "uber://", appStoreID: "123")
    
    Group {
        OpenAppButton(app)
        
        OpenAppButton(app) {
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
    let deeplink: String
    let appStoreID: String
    
    static var appName: String {
        Bundle.main.object(forInfoDictionaryKey: kCFBundleNameKey as String) as! String
    }
    
    static var bundleID: String {
        Bundle.main.bundleIdentifier!
    }
    
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString" as String) as! String
    }
    
    static var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as! String
    }
    
    static var fullVersion: String {
        "\(version) (\(buildNumber))"
    }
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
            openURL(URL(string: app.deeplink)!) { canOpen in
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

