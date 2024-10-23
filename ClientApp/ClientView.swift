// Copyright © 2024 Zama. All rights reserved.

import SwiftUI

struct ClientView: View {
    @StateObject private var viewModel = ViewModel()
    @State private var screenshot: UIImage?
    @Environment(\.scenePhase) var scenePhase
    
    var body: some View {
        VStack {
            header
            
            list
            
            Spacer()
        }
        .tint(.pink)
        .buttonStyle(.bordered)
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                Task {
                    try await viewModel.loadFromDisk()
                }
            case _: break
            }
        }
        .overlay {
            if let screenshot {
                GroupBox("Screenshot") {
                    Image(uiImage: screenshot)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding()
                        .border(.white, width: 8)
                        .rotationEffect(.degrees(-1.5))
                        .shadow(radius: 5)
                }.padding()
            }
        }
    }
    
    private var header: some View {
        VStack {
            HStack(spacing: 0) {
                Text("Client ")
                Text("FHE").foregroundColor(.pink)
                Text("alth")
            }
            .bold()
            .font(.largeTitle)
            
            Text("All Information Encrypted and Private")
                .bold()
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    @ViewBuilder
    private var list: some View {
        VStack {
            Group {
                if let data = viewModel.encryptedWeight {
                    encryptedFileRow("\(Storage.File.weightList.rawValue)", data: data)
                    uploadButton
                    secureDisplay
                } else {
                    ContentUnavailableView {
                        Label("No encrypted health records", systemImage: "heart.text.clipboard")
                            .symbolRenderingMode(.multicolor)
                    } description: {
                        Text("Generate encrypted health records\nusing Bridge App.")
                    } actions: {
                        Link("Open Bridge App", destination: URL(string: "bridgeapp://")!)
                    }
                }
            }
            .padding(8)
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.1))
            }
        }
        .padding()
    }
    
    private func encryptedFileRow(_ title: String, data: Data) -> some View {
        HStack {
            Image(systemName: "document.fill")
            Text(title)
            Text(data.formattedSize).foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.vertical, 8)
    }
    
    private var uploadButton: some View {
        AsyncButton(action: viewModel.upload) {
            Text("Upload")
                .frame(width: 150, alignment: .center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
    
    @ViewBuilder
    private var secureDisplay: some View {
        secureItem("Weight History", file: .weightList, data: viewModel.encryptedWeight)

        HStack {
            secureItem("Avg", file: .weightAvg, data: viewModel.encryptedAvg)
            secureItem("Min", file: .weightMin, data: viewModel.encryptedMin)
            secureItem("Max", file: .weightMax, data: viewModel.encryptedMax)
        }
    }
    
    func secureItem(_ title: String, file: Storage.File, data: Data?) -> some View {
        VStack {
            if data != nil {
                SecureDisplay(url: Storage.url(for: file))
            } else {
                Image(systemName: "questionmark")
                    .frame(maxWidth: .infinity, maxHeight: 150)
                    .background(.black)
                    .cornerRadius(12)
            }
            Text(title)
        }
    }
}

#Preview {
    ClientView()
}

@main
struct ClientApp: App {
    var body: some Scene {
        WindowGroup {
            ClientView()
        }
    }
}

