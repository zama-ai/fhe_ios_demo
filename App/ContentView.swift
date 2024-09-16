// Copyright © 2024 Zama. All rights reserved.

import SwiftUI
import MyRustLib

struct ContentView: View {
    @State private var result = "?"
    
    var body: some View {
        VStack {
            Text("Hello, FHE!").font(.title)
            
            Spacer(minLength: 40).fixedSize()
            
            HStack(spacing: 0) {
                Text("42 + 42 = ")
                Text("000")
                    .hidden()
                    .overlay {
                        Text(result)
                    }
            }
            Button("Run Rust") {
                result = String("\(magicAdd(42, 42))")
            }.buttonStyle(.bordered)
            
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
