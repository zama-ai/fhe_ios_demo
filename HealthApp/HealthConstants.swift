// Copyright © 2025 Zama. All rights reserved.

import Foundation

enum Constants {
    @UserDefaultsStorage(key: "v11.selectedNight", defaultValue: nil)
    static var selectedNight: Date?

    @UserDefaultsStorage(key: "v11.selectedNightInputPreviewString", defaultValue: nil)
    private static var _selectedNightInputPreviewString: String?
    static var selectedNightInputPreviewURL: URL? {
        get {
            _selectedNightInputPreviewString.flatMap(URL.init(string:))
        } set {
            _selectedNightInputPreviewString = newValue?.absoluteString
        }
    }

    @UserDefaultsStorage(key: "v11.selectedNightResultPreviewString", defaultValue: nil)
    private static var _selectedNightResultPreviewString: String?
    static var selectedNightResultPreviewURL: URL? {
        get {
            _selectedNightResultPreviewString.flatMap(URL.init(string:))
        } set {
            _selectedNightResultPreviewString = newValue?.absoluteString
        }
    }
    
    @UserDefaultsStorage(key: "v11.uploadedServerKeyHash", defaultValue: nil)
    static var uploadedServerKeyHash: String?
    
    @UserDefaultsStorage(key: "v11.uploadedServerKeyHash", defaultValue: nil)
    static var uploadedServerKeyUID: Network.UID?
}
