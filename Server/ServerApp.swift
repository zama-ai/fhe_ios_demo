// Copyright © 2024 Zama. All rights reserved.

import SwiftUI

struct ServerView: View {
    @State private var serverKey: String?
    @State private var input: Data?
    @State private var output: Data?
    @Environment(\.scenePhase) var scenePhase

    var body: some View {
        VStack(spacing: 30) {
            Text("FHE Server App")
                .font(.largeTitle)
            
            Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90.icloud.fill")
                .foregroundStyle(.yellow)
                .font(.system(size: 50))
            
            VStack {
                LabeledContent("ServerKey", value: serverKey ?? "nil")
                LabeledContent("Input", value: formatData(input))
                LabeledContent("Output", value: formatData(output))
            }.frame(width: 200)
            
            Button("Increment") {
                if let input = FHEEngine.shared.readSharedData(key: .input) {
                    
                    // Easy: no transform, just copy input
                    // FHEEngine.shared.writeSharedData(input, key: .output)
                    
                    // Actually compute. output = input + 42
                    let computed = FHEEngine.shared.fheComputeOnEncryptedData(input: input)
                    FHEEngine.shared.writeSharedData(computed, key: .output)
                    
                    reloadFromDisk()
                } else {
                    print("no input found")
                }
            }.tint(.yellow)
            
            Button("Reset disk", role: .destructive) {
                FHEEngine.shared.writeSharedData(nil, key: .input)
                FHEEngine.shared.writeSharedData(nil, key: .output)
                reloadFromDisk()
            }
            
            Spacer()
        }
        .buttonStyle(.bordered)
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active: reloadFromDisk()
            case _: break
            }
        }
    }
    
    func formatData(_ data: Data?) -> String {
        data.map({
            "\($0.count.formatted(.byteCount(style: .file)))"
        }) ?? "nil"
    }
    
    func reloadFromDisk() {
        FHEEngine.shared.loadServerKey { size in
            if let size {
                serverKey = size.formatted(.byteCount(style: .file))
            } else {
                serverKey = "nil"
            }
        }
        
        input = FHEEngine.shared.readSharedData(key: .input)
        output = FHEEngine.shared.readSharedData(key: .output)
    }
}

#Preview {
    ServerView()
}

@main
struct ServerApp: App {
    var body: some Scene {
        WindowGroup {
            ServerView()
        }
    }
}
