// Copyright © 2025 Zama. All rights reserved.

import SwiftUI

#Preview {
    Group {
        CopyableText("This is some copyable text.")
        
        CopyableText("This is some copyable text.")
            .font(.largeTitle)
        
        CopyableText("This is some copyable text.")
            .font(.caption2)
    }
    .padding()
    .border(.secondary)
}


struct CopyableText: View {
    let text: String?
    
    @State private var justCopied: Bool = false
    
    init(_ text: String?) {
        self.text = text
    }
    
    var body: some View {
        if let text {
            Text(text)
                .padding(.trailing, 24)
                .overlay(alignment: .trailingFirstTextBaseline) {
                    Button(action: copyToClipboard) {
                        Image(systemName: justCopied ? "checkmark" : "doc.on.doc")
                    }
                    .buttonStyle(.borderless)
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
