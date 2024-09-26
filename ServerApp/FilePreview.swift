// Copyright © 2024 Zama. All rights reserved.

import SwiftUI
import QuickLook

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
