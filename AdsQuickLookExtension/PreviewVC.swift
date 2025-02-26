// Copyright © 2025 Zama. All rights reserved.

import UIKit
import SwiftUI
import QuickLook

final class PreviewVC: UIViewController, QLPreviewingController {

    @IBOutlet private var container: UIView!
    private var viewModel =  ViewModel()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let swiftUIView = PreviewContent(viewModel: viewModel)
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
        let suffix = url.deletingPathExtension().lastPathComponent.split(separator: "-").last ?? "0"
        let position = Int(suffix) ?? 0
        print("Rendering ", url.lastPathComponent, suffix, position)
        
//        guard let data = await Storage.read(url),
//              let ck = try await ClientKey.readFromDisk(.clientKey)
//        else {
//            print("QL: cannot read ClientKey or file at \(url)")
//            throw NSError(domain: "App", code: 1, userInfo: [NSLocalizedDescriptionKey: "QL: cannot read ClientKey or file at \(url)!"])
//        }
        
        // Decryption…
        
        self.viewModel.adID = position
    }
}
