// Copyright © 2024 Zama. All rights reserved.

import SwiftUI

struct ServerView: View {
    @State private var sk: ServerKeyCompressed?
    @State private var input: FHEUInt16?
    
    @Environment(\.scenePhase) var scenePhase

    var body: some View {
        VStack(spacing: 20) {
            header
                        
            VStack(spacing: 8) {
                LabeledContent("ServerKey", value: formatData(sk))
                LabeledContent("Encrypted Input", value: formatData(input))
            }
            .frame(width: 250)
            .padding(.leading, 32)
            
            AsyncButton("Compute", action: serverTest)
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
    
    @ViewBuilder
    private var header: some View {
        VStack {
            Text("\(Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90.icloud.fill")) Server")
                .bold()
                .font(.largeTitle)
                .foregroundColor(.yellow)
            
            Text("Where FHE compute occurs")
                .bold()
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 24)
    }

    func reloadFromDisk() {
        Task { @MainActor in
            self.sk = try? await ServerKeyCompressed.readFromDisk(.serverKey)
            try self.sk?.setServerKey()
            
            self.input = try? await FHEUInt16.readFromDisk(.ageIn)
        }
    }

    func formatData(_ item: Persistable?) -> String {
        (try? item?.toData())?.formattedSize ?? "nil"
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
