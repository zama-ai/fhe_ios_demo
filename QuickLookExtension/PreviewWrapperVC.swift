// Copyright © 2024 Zama. All rights reserved.

import UIKit
import SwiftUI
import QuickLook

final class PreviewWrapperVC: UIViewController, QLPreviewingController {

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

    func preparePreviewOfFile(at url: URL) async throws {
        guard let data = try await Storage.read(url),
              let ck = try await ClientKey.readFromDisk(.clientKey) else {
            print("QL: cannot read ClientKey or file at \(url)")
            throw NSError(domain: "App", code: 1, userInfo: [NSLocalizedDescriptionKey: "QL: cannot read ClientKey or file at \(url)!"])
        }
        
        let file = try FHERenderable(fromData: data)
        switch file.type {
            case .uint16:
            let encrypted = try FHEUInt16(fromData: file.data)
            let clearInt = try encrypted.decrypt(clientKey: ck)
            viewModel.data = .int(clearInt)
            
            case .uint16Array:
            let encrypted = try FHEUInt16Array(fromData: file.data)
            let clearArray = try encrypted.decrypt(clientKey: ck)
            viewModel.data = .array(clearArray)
        }
    }
}
