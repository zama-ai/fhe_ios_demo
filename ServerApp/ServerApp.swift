// Copyright © 2024 Zama. All rights reserved.

import SwiftUI

struct ServerView: View {
    @State private var serverKey: String?
    @State private var input: Data?
    @State private var output: Data?
    @State private var outputURL: URL?

    @Environment(\.scenePhase) var scenePhase

    var body: some View {
        VStack(spacing: 20) {
            Text("FHE Server App")
                .font(.largeTitle)
            
            Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90.icloud.fill")
                .foregroundStyle(.yellow)
                .font(.system(size: 50))
            
            VStack(spacing: 8) {
                HStack {
                    LabeledContent("ServerKey", value: serverKey ?? "nil")
                    DeleteButton(action: {}).hidden()
                }
                HStack {
                    LabeledContent("Encrypted Input", value: formatData(input))
                    DeleteButton(action: clearInput)
                }
                HStack {
                    LabeledContent("Encrypted Output", value: formatData(output))
                    DeleteButton(action: clearOutput)
                }
            }
            .frame(width: 250)
            .padding(.leading, 32)
            
            AsyncButton("Compute Predictions", action: computePredictions)
                .buttonStyle(.bordered)
                        
            Spacer()
        }
        .tint(.yellow)
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active: reloadFromDisk()
            case _: break
            }
        }
    }
    
    func clearInput() {
        FHEEngine.shared.writeSharedData(nil, key: .input)
        reloadFromDisk()
    }
    
    func clearOutput() {
        FHEEngine.shared.writeSharedData(nil, key: .output)
        reloadFromDisk()
    }

    func computePredictions() async {
        guard let input = FHEEngine.shared.readSharedData(key: .input) else {
            print("no input found")
            return
        }
        
        if let computed = FHEEngine.shared.fheComputeOnEncryptedData(input: input) {
        
            FHEEngine.shared.writeSharedData(computed, key: .output)
        
            FHEEngine.shared.writeToDisk(computed, fileName: "computationResult.fheencrypted") { result in
                switch result {
                case .success(let url):
                    print(".fheencrypted saved. open \(url.absoluteString)")
                    outputURL = url
                    
                case .failure(let error):
                    print("failed to save .fheencrypted \(error)")
                }
            }
        }
        reloadFromDisk()
    }
            
    func formatData(_ data: Data?) -> String {
        data.map({
            "\($0.count.formatted(.byteCount(style: .file)))"
        }) ?? "nil"
    }
    
    func reloadFromDisk() {
        Task { @MainActor in
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

struct DeleteButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(role: .destructive, action: action) {
            Image(systemName: "trash")
        }.buttonStyle(.borderless)
    }
}

