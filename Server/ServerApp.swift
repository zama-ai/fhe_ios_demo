// Copyright © 2024 Zama. All rights reserved.

import SwiftUI

struct ServerView: View {
    @State private var input: Int?
    @State private var output: Int?
    @Environment(\.scenePhase) var scenePhase

    var body: some View {
        VStack(spacing: 30) {
            Text("FHE Server App")
                .font(.largeTitle)
            
            Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90.icloud.fill")
                .foregroundStyle(.yellow)
                .font(.system(size: 50))
            
            VStack {
                LabeledContent("Input", value: input.map({ "\($0)" }) ?? "nil")
                LabeledContent("Output", value: output.map({ "\($0)" }) ?? "nil")
            }.frame(width: 100)
            
            Button("Increment") {
                if let input = FHEEngine.shared.readSharedValue(key: .input) {
                    FHEEngine.shared.writeSharedValue(input + 42, key: .output)
                    reloadFromDisk()
                } else {
                    print("no input found")
                }
                //FHEEngine.shared.encryptInt(44)
            }.tint(.yellow)
            
            Button("Reset disk", role: .destructive) {
                FHEEngine.shared.writeSharedValue(nil, key: .input)
                FHEEngine.shared.writeSharedValue(nil, key: .output)
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
    
    func reloadFromDisk() {
        input = FHEEngine.shared.readSharedValue(key: .input)
        output = FHEEngine.shared.readSharedValue(key: .output)
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
