// Copyright © 2025 Zama. All rights reserved.

import SwiftUI

#Preview {
    ConsoleSection(title: "FHE Encryption", output: "Sample console output…")
        .padding()
}

struct ConsoleSection: View {
    let title: String
    let output: String
    @State private var isExpanded: Bool = true
    
    var body: some View {
        VStack {
            HStack {
                Text(title)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .customFont(.title3)
                Spacer()
                Toggle("Show", isOn: $isExpanded)
                    .labelsHidden()
            }
            
            if isExpanded {
                CopyableText(output, fullWidth: true)
                    .customFont(.caption)
                    .fontDesign(.monospaced)
                    .padding(8)
                    .frame(minHeight: 200, alignment: .topLeading)
                    .background(Color.zamaGreyConsole)
                    .tint(.black)
            }
        }
    }
}
