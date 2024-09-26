// Copyright © 2024 Zama. All rights reserved.

import SwiftUI

struct ServerView: View {
    @State private var serverKey: String?
    @State private var input: Data?
    @State private var output: Data?
    @State private var isComputing: Bool = false
    @State private var outputURL: URL?
    @State private var inlinePreviewURL: URL?
    @State private var screenshot: UIImage?

    @Environment(\.scenePhase) var scenePhase

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("FHE Server App")
                    .font(.largeTitle)
                
                Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90.icloud.fill")
                    .foregroundStyle(.yellow)
                    .font(.system(size: 50))
                    .symbolEffect(.rotate, isActive: isComputing)
                
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
                
                HStack {
                    Button("Compute", action: compute)
                    
                    Button("Show Result", action: showResultInline)
                        .disabled(outputURL == nil)
                    
                    Button {
                        if let image = takeScreenshot() {
                            self.screenshot = image
                        } else {
                            print("screenshot is nil")
                        }
                    } label: {
                        Image(systemName: "eyes")
                    }
                }

                if let inlinePreviewURL {
                    GroupBox("Clear Result") {
                        FilePreview(url: inlinePreviewURL, showTools: false)
                            .frame(minWidth: 200, minHeight: 150)
                    }.padding()
                }
                
                if let screenshot {
                    GroupBox("Screenshot") {
                        Image(uiImage: screenshot)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .border(.white, width: 8)
                            .rotationEffect(.degrees(-1.5))
                            .shadow(radius: 5)
                    }.padding()
                }
            }
        }
        .tint(.yellow)
        .buttonStyle(.bordered)
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

    func showResultInline() {
        inlinePreviewURL = outputURL
    }

    func compute() {
        isComputing = true

        Task {
            if let input = FHEEngine.shared.readSharedData(key: .input) {
                let computed = FHEEngine.shared.fheComputeOnEncryptedData(input: input)
                
                // Persist computed for Bridge App
                FHEEngine.shared.writeSharedData(computed, key: .output)
                
                if let computed {
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
                Task { @MainActor in
                    isComputing = false
                }
            } else {
                print("no input found")
            }
        }
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
