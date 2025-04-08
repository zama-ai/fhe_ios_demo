// Copyright © 2025 Zama. All rights reserved.

import UIKit
import SwiftUI
import QuickLook

final class PreviewVC: UIViewController, QLPreviewingController {
    
    @IBOutlet private var container: UIView!
    private var viewModel = PreviewContent.ViewModel()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let swiftUIView = PreviewContent(viewModel: viewModel).securelyDisplayed()
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
        guard let data = await Storage.read(url) else {
            print("QL: cannot read file at \(url)")
            throw NSError(domain: "App", code: 1, userInfo: [NSLocalizedDescriptionKey: "QL: cannot read file at \(url)"])
        }
        
        guard let ck = try await ClientKey.readFromDisk(.clientKey) else {
            print("QL: cannot read ClientKey")
            throw NSError(domain: "App", code: 1, userInfo: [NSLocalizedDescriptionKey: "QL: cannot read ClientKey"])
        }
        
        let fileName = url.lastPathComponent
        let fileNameForDeterminingType = fileName.replacingOccurrences(of: "-preview", with: "")
        var fileType = Storage.File(rawValue: fileNameForDeterminingType)?.decryptType
        
        if fileType == nil {
            if fileName.starts(with: "weightList") {
                fileType = Storage.File.weightList.decryptType
            } else if fileName.starts(with: "sleepList") {
                fileType = Storage.File.sleepList.decryptType
            } else if fileName.starts(with: "sleepScore") {
                fileType = Storage.File.sleepScore.decryptType
            }
        }
        
        guard let fileType else {
            throw NSError(domain: "App", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unknown file type at \(url)!"])
        }
        
        let isForSmallPreview = fileName.contains("-preview")
        
        switch fileType {
        case .int8:
            let encrypted = try FHEUInt8(fromData: data)
            let clearInt = try encrypted.decrypt(clientKey: ck)
            if isForSmallPreview {
                viewModel.data = .previewSleepQuality(quality: SleepQuality(rawValue: clearInt)!)
            } else {
                viewModel.data = .gauge(value: clearInt)
            }
            
        case .int16:
            let encrypted = try FHEUInt16(fromData: data)
            let clearInt = try encrypted.decrypt(clientKey: ck)
            let res: Double = Double(clearInt) / 10.0
            
            if isForSmallPreview {
                viewModel.data = .previewText(value: res)
            } else {
                viewModel.data = .text(value: res)
            }
            
        case .array:
            let encrypted = try FHEUInt16Array(fromData: data)
            let clearArray = try encrypted.decrypt(clientKey: ck).map { Double($0) / 10.0 }
            viewModel.data = .simpleChart(clearArray)
            
        case .cipherTextList:
            let encrypted = try CompactCiphertextList(fromData: data)
            let clearNight = try encrypted.decrypt(clientKey: ck)
            if isForSmallPreview {
                let duration = (clearNight.last?.end ?? 0) * 60
                viewModel.data = .previewSleepDuration(duration: TimeInterval(duration))
            } else {
                viewModel.data = .sleepChart(clearNight)
            }
        }
    }
}
