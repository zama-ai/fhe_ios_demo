// Copyright © 2024 Zama. All rights reserved.

import SwiftUI
import QuickLook

struct SecureDisplay: View {
    let url: URL
    
    var body: some View {
        FilePreview(url: url)
            .frame(maxHeight: 150)
    }
}

struct FilePreview: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIViewController {
        let vc = QLPreviewController()
        vc.dataSource = context.coordinator
        return vc
    }

    func updateUIViewController(_ vc: UIViewController, context _: Context) {
    }

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
    SecureDisplay(url: Bundle.main.bundleURL)
        .border(.secondary)
        .padding()
}
