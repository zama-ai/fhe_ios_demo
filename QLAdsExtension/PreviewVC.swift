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
        
        guard let resultData = await Storage.read(url),
              let savedPK = await Storage.read(.concretePrivateKey),
              let cryptoParams = ConcreteML.cryptoParams
        else {
            print("QL: cannot read ClientKey or file at \(url)")
            throw NSError(domain: "App", code: 1, userInfo: [NSLocalizedDescriptionKey: "QL: cannot read ClientKey or file at \(url)!"])
        }
        
        // Decryption…
        let privateKey = await ConcreteML.deserializePrivateKey(from: savedPK)
        let compressedMatrix = try compressedResultEncryptedMatrixDeserialize(content: resultData)
        let rawResult: [[UInt64]] = try decryptMatrix(compressedMatrix: compressedMatrix,
                                                      privateKey: privateKey,
                                                      cryptoParams: cryptoParams,
                                                      numValidGlweValuesInLastCiphertext: 42) // Concrete ML hack
        
        let clearResult: [Int64] = rawResult[0].compactMap {
            let raw = Int64(truncatingIfNeeded: $0)
            return raw <= 0 ? 0 : raw
        }
        
        self.viewModel.adID = nthHighestScore(rank: position, in: clearResult)
        
        print(clearResult)
        print("For Ad at position \(position), display ad \(self.viewModel.adID!)")
    }
    
    /// Returns the index of the `rank`th highest score in the given list.
    ///
    /// - Parameters:
    ///   - rank: The position (0-based) of the desired item, where `0` is the highest.
    ///   - scores: A list of numerical scores.
    /// - Returns: The index of the `rank`th highest score.
    ///
    /// - Example:
    ///   ```swift
    ///   let scores: [UInt64] = [10, 50, 12, 32]
    ///   nthHighestScore(rank: 0, in: scores) // → 1 (highest score: 50)
    ///   nthHighestScore(rank: 1, in: scores) // → 3 (second highest: 32)
    ///   nthHighestScore(rank: 2, in: scores) // → 2 (third highest: 12)
    ///   nthHighestScore(rank: 3, in: scores) // → 0 (fourth highest: 10)
    ///   ```
    private func nthHighestScore(rank: Int, in scores: [Int64]) -> Int {
        let positions = scores.enumerated()
            .sorted { $0.element > $1.element } // highest scores first
            .map { $0.offset }
        return positions[rank]
    }
}
