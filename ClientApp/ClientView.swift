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
        .padding(.top, 24)
    }
    
    private var list: some View {
        VStack {
            Group {
                if let data = viewModel.encryptedWeight {
                    encryptedFileRow("\(Storage.File.weightList.rawValue)", data: data)
                    uploadButton
                    secureDisplay
                } else {
                    ContentUnavailableView("No encrypted info found on disk", systemImage: "doc.questionmark")
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
        secureItem("Weight History", file: .weightList)

        HStack {
            secureItem("Avg", file: .weightAvg)
            secureItem("Min", file: .weightMin)
            secureItem("Max", file: .weightMax)
        }
        .frame(height: 100)
    }
    
    func secureItem(_ title: String, file: Storage.File) -> some View {
        VStack {
            SecureDisplay(url: Storage.url(for: file))
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

