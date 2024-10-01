// Copyright © 2024 Zama. All rights reserved.

import SwiftUI

struct ServerView: View {
    @State private var sk: ServerKey?
    @State private var csk: CompressedServerKey?
    @State private var input: FHEUInt16?
    
    @Environment(\.scenePhase) var scenePhase

    var body: some View {
        VStack(spacing: 20) {
            Text("FHE Server App")
                .font(.largeTitle)
            
            Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90.icloud.fill")
                .foregroundStyle(.yellow)
                .font(.system(size: 50))
            
            VStack(spacing: 8) {
                LabeledContent("ServerKey", value: formatData(sk))
                LabeledContent("Compressed ServerKey", value: formatData(csk))
                LabeledContent("Encrypted Input", value: formatData(input))
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
    
    func reloadFromDisk() {
        Task { @MainActor in
            self.sk = try? await ServerKey.readFromDisk()
            self.csk = try? await CompressedServerKey.readFromDisk()
            try self.csk?.setServerKey()
            
            self.input = try? await FHEUInt16.readFromDisk()
        }
    }

    func formatData(_ item: Persistable?) -> String {
        (try? item?.toData())?.formattedSize ?? "nil"
    }

    func computePredictions() async throws {
        guard let input else { return }
        let computed = try input.addScalar(int: 10)
        try await Storage.write(.encryptedOutput, data: computed.toData())
        reloadFromDisk()
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
