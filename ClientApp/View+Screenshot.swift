// Copyright © 2024 Zama. All rights reserved.

import SwiftUI

extension View {
    func takeScreenshot() -> UIImage? {
        let controller = UIHostingController(rootView: self)
        let targetSize = CGSizeMake(UIScreen.main.bounds.width, UIScreen.main.bounds.height)

        let view = controller.view
        view?.bounds = CGRect(origin: .zero, size: targetSize)
        view?.backgroundColor = .clear
        
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        
        return renderer.image { _ in
            view?.drawHierarchy(in: CGRect(origin: .zero, size: targetSize), afterScreenUpdates: true)
        }
    }
}
