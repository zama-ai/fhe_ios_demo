// Copyright © 2025 Zama. All rights reserved.

import Foundation

enum ZamaConfig {
    static let rootAPI = URL(string: "https://api.zama.ai:443")!
    static let websiteLandingPage = URL(string: "https://www.zama.ai")!
    static let websiteFHEIntro = URL(string: "https://www.zama.ai/introduction-to-homomorphic-encryption")!
}

extension AppInfo {
    static let appleHealth = {
        AppInfo(name: "Apple Health",
                deeplink: "x-apple-health://",
                appStoreID: "1242545199")
    }()
    
    static func zamaDataVault(tab: DataVaultTab) -> AppInfo {
        AppInfo(name: "Zama Data Vault",
                deeplink: "zamadatavault://\(tab.rawValue)",
                appStoreID: "6738993762")
    }
    
    static func fheHealth(tab: HealthTab) -> AppInfo {
        AppInfo(name: "FHE Health",
                deeplink: "fhehealth://\(tab.rawValue)",
                appStoreID: "6738993713")
    }
    
    static let fheAds = {
        AppInfo(name: "FHE Ads",
                deeplink: "fheads://",
                appStoreID: "6739003587")
    }()
}

enum DataVaultTab: String {
    case home = "home"
    case sleep = "sleep"
    case weight = "weight"
    case profile = "profile"
    
    var displayInfo: (name: String, icon: String) {
        switch self {
        case .home: (name: "Home", icon: "house")
        case .sleep: (name: "Sleep", icon: "bed.double.fill")
        case .weight: (name: "Weight", icon: "scalemass.fill")
        case .profile: (name: "Profile", icon: "person.text.rectangle.fill")
        }
    }
    
    init?(url: URL) {
        guard let host = url.host(), let tab = DataVaultTab(rawValue: host) else {
            return nil
        }
        self = tab
    }
}

enum HealthTab: String {
    case home = "home"
    case sleep = "sleep"
    case weight = "weight"
    
    var displayInfo: (name: String, icon: String) {
        switch self {
        case .home: (name: "Home", icon: "house")
        case .sleep: (name: "Sleep", icon: "bed.double.fill")
        case .weight: (name: "Weight", icon: "scalemass.fill")
        }
    }
    
    init?(url: URL) {
        guard let host = url.host(), let tab = HealthTab(rawValue: host) else {
            return nil
        }
        self = tab
    }
}
