// Copyright © 2024 Zama. All rights reserved.

import SwiftUI
import QuickLook

typealias FHEEncryptedInt16 = Data
typealias FHEEncryptedArrayInt16 = Data

struct PrivateText: View {
    let url: URL // FHEEncryptedInt16
    var body: some View {
        FilePreview(url: url, //Bundle.main.bundleURL,
                    showTools: false)
        .frame(maxHeight: 150)
        .border(.secondary)
    }
}

struct FilePreview: UIViewControllerRepresentable {
    let url: URL
    let showTools: Bool

    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = QLPreviewController()
        viewController.dataSource = context.coordinator
        if showTools {
            return UINavigationController(rootViewController: viewController)
        } else {
            return viewController
        }
    }

    func updateUIViewController(_: UIViewController, context _: Context) { }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: QLPreviewControllerDataSource {
        let parent: FilePreview

        init(parent: FilePreview) {
            self.parent = parent
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            1
        }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            parent.url as NSURL
        }
    }
}

#Preview {
    let url = Bundle.main.bundleURL
    Group {
        FilePreview(url: url, showTools: true)
        FilePreview(url: url, showTools: false)
    }
    .border(.secondary)
    .padding()
}
