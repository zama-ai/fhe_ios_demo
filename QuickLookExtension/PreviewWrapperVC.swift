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
        let result = try await readClearResult(at: url)
        viewModel.text = "Prediction is \(result)%"
    }
}

import TFHE
extension PreviewWrapperVC {
    private func readClearResult(at url: URL) async throws -> Int {
        let _ = FHEEngine.shared
        try? await Task.sleep(for: .seconds(0.5)) // Hack to wait for client_key loading

        return try await withCheckedThrowingContinuation { continuation in
            FHEEngine.readFile(named: url.lastPathComponent) { result in
                switch result {
                case .success(let data):
                    let clearOutput = FHEEngine.shared.decryptInt(data: data)
                    continuation.resume(returning: clearOutput)
                    
                case .failure(let error):
                    print("No crypted file to read from, \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
