// Copyright © 2025 Zama. All rights reserved.

import Foundation

enum Constants {
    @UserDefaultsStorage(key: "v12.selectedNight", defaultValue: nil)
    static var selectedNight: Date?

    @UserDefaultsStorage(key: "v12.selectedNightInputPreviewString", defaultValue: nil)
    private static var _selectedNightInputPreviewString: String?
    static var selectedNightInputPreviewURL: URL? {
        get {
            _selectedNightInputPreviewString.flatMap(URL.init(string:))
        } set {
            _selectedNightInputPreviewString = newValue?.absoluteString
        }
    }

    @UserDefaultsStorage(key: "v12.selectedNightResultPreviewString", defaultValue: nil)
    private static var _selectedNightResultPreviewString: String?
    static var selectedNightResultPreviewURL: URL? {
        get {
            _selectedNightResultPreviewString.flatMap(URL.init(string:))
        } set {
            _selectedNightResultPreviewString = newValue?.absoluteString
        }
    }
    
    @UserDefaultsStorage(key: "v12.uploadedServerKeyHash", defaultValue: nil)
    static var uploadedServerKeyHash: String?
    
    @UserDefaultsStorage(key: "v12.uploadedServerKeyUID", defaultValue: nil)
    static var uploadedServerKeyUID: Network.UID?
}
