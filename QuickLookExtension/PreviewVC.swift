// Copyright © 2025 Zama. All rights reserved.

import UIKit
import SwiftUI
import QuickLook

final class PreviewVC: UIViewController, QLPreviewingController {
    
    @IBOutlet private var container: UIView!
    private var viewModel = SecureView.ViewModel()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let swiftUIView = SecureView(viewModel: viewModel)
        let hostingController = UIHostingController(rootView: swiftUIView)
        addChild(hostingController)
        
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(hostingController.view)
        
        container.backgroundColor = .clear
        hostingController.view.backgroundColor = .clear
        
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: container.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        hostingController.didMove(toParent: self)
    }
    
    // Add the supported content types to the QLSupportedContentTypes array in the Info.plist of the extension.
    // Perform any setup necessary in order to prepare the view.
    // Quick Look will display a loading spinner until this returns.
    func preparePreviewOfFile(at url: URL) async throws {
        guard let data = await Storage.read(url),
              let ck = try await ClientKey.readFromDisk(.clientKey) else {
            print("QL: cannot read ClientKey or file at \(url)")
            throw NSError(domain: "App", code: 1, userInfo: [NSLocalizedDescriptionKey: "QL: cannot read ClientKey or file at \(url)!"])
        }
        
        let fileName = url.lastPathComponent
        guard let fileType = Storage.File(rawValue: fileName)?.decryptType else {
            throw NSError(domain: "App", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unknown file type at \(url)!"])
        }
        
        switch fileType {
        case .int8:
            let encrypted = try FHEUInt8(fromData: data)
            let clearInt = try encrypted.decrypt(clientKey: ck)
            viewModel.data = .gauge(value: clearInt,
                                    range: 1...5,
                                    title: "Sleep Quality",
                                    labels: ["Excellent", "Good", "Average", "Poor", "Awful"])
            
        case .int16:
            let encrypted = try FHEUInt16(fromData: data)
            let clearInt = try encrypted.decrypt(clientKey: ck)
            let res: Double = Double(clearInt) / 10.0
            viewModel.data = .text(value: res)
            
        case .array:
            let encrypted = try FHEUInt16Array(fromData: data)
            let clearArray = try encrypted.decrypt(clientKey: ck).map { Double($0) / 10.0 }
            viewModel.data = .simpleChart(clearArray)
            
        case .cipherTextList:
            let encrypted = try CompactCiphertextList(fromData: data)
            let clearNight = try encrypted.decrypt(clientKey: ck)
            viewModel.data = .sleepChart(clearNight)
        }
    }
}
