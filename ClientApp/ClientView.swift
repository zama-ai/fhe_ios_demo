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
        Group {
            if let data = viewModel.sleepInput {
                //secureItem("Sleep History", file: .sleepList, data: data)
                encryptedFileRow(Storage.File.sleepList.rawValue, data: data)
                sleepResults
            } else {
                ContentUnavailableView {
                    Label("No Encrypted Sleep Records", systemImage: "bed.double.fill")
                        .symbolRenderingMode(.multicolor)
                } description: {
                    Text("Generate encrypted sleep records\nusing Bridge App.")
                } actions: {
                    Link("Open Bridge App", destination: URL(string: "bridgeapp://")!)
                }
            }

            if let data = viewModel.weightInput {
                secureItem("Weight History", file: .weightList, data: data)
                weightStats
            } else {
                ContentUnavailableView {
                    Label("No Encrypted Weight Records", systemImage: "figure")
                        .symbolRenderingMode(.multicolor)
                } description: {
                    Text("Generate encrypted weight records\nusing Bridge App.")
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
    
    private func encryptedFileRow(_ title: String, data: Data) -> some View {
        HStack {
            Image(systemName: "document.fill")
            Text(title)
            Text(data.formattedSize).foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.vertical, 8)
    }
    
    private func uploadButton(_ action: @escaping() async throws -> Void) -> some View {
        AsyncButton(action: action) {
            Text("Upload for Analysis")
                .frame(alignment: .center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
    
    @ViewBuilder
    private var weightStats: some View {
        if let a = viewModel.weightResultAvg, let b = viewModel.weightResultMin, let c = viewModel.weightResultMax {
            HStack {
                secureItem("Avg", file: .weightAvg, data: a)
                secureItem("Min", file: .weightMin, data: b)
                secureItem("Max", file: .weightMax, data: c)
            }
        } else {
            uploadButton(viewModel.uploadWeight)
        }
    }

    @ViewBuilder
    private var sleepResults: some View {
        if let a = viewModel.sleepResultQuality {
            secureItem("Sleep Quality", file: .sleepResult, data: a)
        } else {
            uploadButton(viewModel.uploadSleep)
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

