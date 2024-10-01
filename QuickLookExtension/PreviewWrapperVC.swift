// Copyright © 2024 Zama. All rights reserved.

import UIKit
import SwiftUI
import QuickLook

final class PreviewWrapperVC: UIViewController, QLPreviewingController {

    @IBOutlet private var container: UIView!
    private var viewModel = PrivateTextView.ViewModel()

    override func viewDidLoad() {
        super.viewDidLoad()

        let swiftUIView = PrivateTextView(viewModel: viewModel)
        let hostingController = UIHostingController(rootView: swiftUIView)
        addChild(hostingController)

        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(hostingController.view)

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
              let ck = try await ClientKey.readFromDisk() else {
            print("QL: cannot read CK nor file at \(url)")
            throw NSError(domain: "app", code: 42, userInfo: [:])
        }
        
        //try? await Task.sleep(for: .seconds(0.5)) // Hack to wait for client_key loading
        let encrypted = try FHEUInt16(fromData: data)
        let clearText = try encrypted.decrypt(clientKey: ck)
        viewModel.text = "Prediction is \(clearText)%"
    }
}
