// Copyright © 2025 Zama. All rights reserved.

import SwiftUI

#Preview {
    Group {
        CopyableText("This is some copyable text.")
        CopyableText("This is some copyable text.", fullWidth: true)
        
        CopyableText("This is some copyable text.")
            .font(.largeTitle)
        CopyableText("This is some copyable text.", fullWidth: true)
            .font(.largeTitle)
        
        CopyableText("This is some copyable text.")
            .font(.caption2)
    }
    .padding()
    .border(.secondary)
}


struct CopyableText: View {
    let text: String?
    let fullWidth: Bool
    
    @State private var justCopied: Bool = false
    
    init(_ text: String?, fullWidth: Bool = false) {
        self.text = text
        self.fullWidth = fullWidth
    }
    
    var body: some View {
        if let text {
            Text(text)
                .padding(.trailing, 24)
                .frame(maxWidth: fullWidth ? .infinity : nil, alignment: .leading)
                .overlay(alignment: .trailingFirstTextBaseline) {
                    if !text.isEmpty {
                        Button(action: copyToClipboard) {
                            Image(systemName: justCopied ? "checkmark" : "doc.on.doc")
                        }
                        .buttonStyle(.borderless)
                    }
                }
        }
    }
    
    private func copyToClipboard() {
        UIPasteboard.general.string = text
        justCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            justCopied = false
        }
    }
}
