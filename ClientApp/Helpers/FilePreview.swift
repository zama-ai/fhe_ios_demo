// Copyright © 2024 Zama. All rights reserved.

import SwiftUI
import QuickLook

struct SecureDisplay: View {
    let url: URL
    
    var body: some View {
        VStack {
            FilePreview(url: url)
                .frame(maxHeight: 150)
                .border(.secondary)
                .background(.red)
            Text(url.lastPathComponent)
                .font(.caption)
        }
    }
}

struct FilePreview: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIViewController {
        let vc = QLPreviewController()
        vc.view.backgroundColor = .clear
        vc.dataSource = context.coordinator
        return vc
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
    SecureDisplay(url: Bundle.main.bundleURL)
        .border(.secondary)
        .padding()
}
