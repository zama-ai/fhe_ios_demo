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
        //        .onChange(of: scenePhase) { _, newPhase in
        //            switch newPhase {
        //            case .active:
        //                Task {
        //                    try await viewModel.loadFromDisk()
        //                }
        //            case _: break
        //            }
        //        }
        .task {
            try? await viewModel.loadFromDisk()
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
                    encryptedFileRow("weight.fheencrypted", data: data)
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
        SecureDisplay(url: Storage.url(for: .encryptedInputList))
            .frame(height: 120)

        HStack {
            secureCell("Avg", file: .encryptedOutputAvg)
            secureCell("Min", file: .encryptedOutputMin)
            secureCell("Max", file: .encryptedOutputMax)
        }
        .frame(height: 100)
    }
    
    func secureCell(_ title: String, file: Storage.File) -> some View {
        VStack {
            SecureDisplay(url: Storage.url(for: file))
            Text(title)
        }
    }
}

//    @ViewBuilder
//    private var importedView: some View {
//        if let imported = viewModel.imported {
//            GroupBox {
//                importRow("Weight", "figure", color: .purple, data: imported.weightHistory)
//                importRow("Sleep", "bed.double.fill", color: .secondary, data: imported.sleepHistory)
//            }
//
//            AsyncButton("Upload for Analysis") {
//                await upload()
//            }.frame(maxWidth: .infinity)
//                .overlay(alignment: .trailing) {
//                    Button {
//                        if let image = takeScreenshot() {
//                            self.screenshot = image
//                        } else {
//                            print("screenshot is nil")
//                        }
//                    } label: {
//                        Image(systemName: "eyes")
//                    }
//                }
//
//        } else {
//            VStack {
//                Image(systemName: "heart.text.clipboard")
//                    .symbolRenderingMode(.multicolor)
//                    .font(.system(size: 50))
//
//                VStack {
//                    Text("No Health Record")
//                        .font(.system(size: 22, weight: .bold))
//
//                    Text("Import your Health Info to get **insights**.\nData will be **encrypted** and always stays **private**.\nThis app **cannot read** your Health Info.")
//                        .font(.footnote)
//                        .foregroundStyle(.secondary)
//                        .multilineTextAlignment(.center)
//                }
//                .padding(.top, 16)
//                .padding(.bottom, 24)
//
//                AsyncButton("Import Health Info") {
//                    await importData()
//                }.padding(.bottom, 8)
//
//            }.padding(.top, 24)
//        }
//    }
//
//    private func importRow(_ title: String, _ icon: String, color: Color, data: Data?) -> some View {
//        LabeledContent {
//            HStack(spacing: 8) {
//                if let data {
//                    Text(data.formattedSize)
//                        .frame(width: 70)
//                    Text(data.snippet(first: 10))
//                        .lineLimit(1)
//                        .truncationMode(.tail) // Add "..." at the end
//                        .font(.system(size: 14))
//                        .foregroundStyle(.green.opacity(0.7))
//                        .monospaced()
//                        .padding(2)
//                        .background {
//                            RoundedRectangle(cornerRadius: 4)
//                                .fill(.black)
//                        }
//                } else {
//                    Text("Not specified").foregroundStyle(.tertiary)
//                }
//            }
//            .frame(width: 180, alignment: .leading)
//        } label: {
//            HStack {
//                Image(systemName: icon)
//                    .symbolRenderingMode(.multicolor)
//                    .foregroundStyle(color)
//                Text(title)
//            }
//        }
//    }
//
//    @ViewBuilder
//    private var computedView: some View {
//        if let computed = viewModel.computed {
//            VStack {
//                importRow("Prediction", "wand.and.sparkles", color: .yellow, data: computed.lifeExpectancy)
//                let url = Storage.url(for: .encryptedOutput)
//                PrivateText(url: url)
//            }
//        }
//    }
//
//    // MARK: - ACTIONS -
//    private func importData() async {
//        if let encryptedData = try? await Storage.read(.encryptedIntInput) {
//            viewModel.imported = .init(weightHistory: encryptedData,
//                                       sleepHistory: encryptedData)
//        }
//    }
//
//    private func upload() async {}
//
//    private func reset() {
//        viewModel.imported = nil
//        viewModel.computed = nil
//    }

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

