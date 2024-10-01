// Copyright © 2024 Zama. All rights reserved.

import SwiftUI

struct AnalysisView: View {
    @State private var isAnimatingTitle = false
    @StateObject private var viewModel: ViewModel
    @State private var screenshot: UIImage?
    @Environment(\.scenePhase) var scenePhase

    init() {
        self._viewModel = StateObject(wrappedValue: ViewModel.empty)
    }
    
    var body: some View {
        VStack {
            header
                .padding(.top, 24)
                .padding(.bottom, 24)
            
            importedView
            computedView
            
            Spacer()
        }
        .tint(.pink)
        .buttonStyle(.bordered)
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                Task {
                    await reloadFromDisk()
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
    
    @ViewBuilder
    private var header: some View {
        VStack {
            HStack(spacing: 0) {
                Text("My sa")
                
                if isAnimatingTitle {
                    Text("FHE")
                        .foregroundColor(.pink)
                } else {
                    Text("fe He")
                }
                
                Text("alth")
            }
            .bold()
            .font(.largeTitle)
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.5), value: isAnimatingTitle)
            
            Text("Private and secure Health Analysis")
                .bold()
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }.task {
            try? await Task.sleep(for: .seconds(1))
            isAnimatingTitle.toggle()
        }.onTapGesture {
            isAnimatingTitle.toggle()
            reset()
        }
    }
    
    @ViewBuilder
    private var importedView: some View {
        if let imported = viewModel.imported {
            GroupBox {
                importRow("Age", "person.text.rectangle", color: .secondary, data: imported.age)
                importRow("Sex", "person.text.rectangle", color: .secondary, data: imported.sex)
                importRow("Blood Type", "person.text.rectangle", color: .secondary, data: imported.bloodType)
                Divider()
                importRow("Weight", "figure", color: .purple, data: imported.weightHistory)
                importRow("Sleep", "bed.double.fill", color: .secondary, data: imported.sleepHistory)
                importRow("Heart rate", "heart.fill", color: .secondary, data: imported.heartRateHistory)
            }
            
            AsyncButton("Upload for Analysis") {
                await upload()
            }.frame(maxWidth: .infinity)
                .overlay(alignment: .trailing) {
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
            
        } else {
            VStack {
                Image(systemName: "heart.text.clipboard")
                    .symbolRenderingMode(.multicolor)
                    .font(.system(size: 50))

                VStack {
                    Text("No Health Record")
                        .font(.system(size: 22, weight: .bold))
                    
                    Text("Import your Health Info to get **insights**.\nData will be **encrypted** and always stays **private**.\nThis app **cannot read** your Health Info.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 16)
                .padding(.bottom, 24)
                
                AsyncButton("Import Health Info") {
                    await importData()
                }.padding(.bottom, 8)
                
            }.padding(.top, 24)
        }
    }
    
    private func importRow(_ title: String, _ icon: String, color: Color, data: Data?) -> some View {
        LabeledContent {
            HStack(spacing: 8) {
                if let data {
                    Text(data.formattedSize)
                        .frame(width: 70)
                    Text(data.snippet(first: 10))
                        .lineLimit(1)
                        .truncationMode(.tail) // Add "..." at the end
                        .font(.system(size: 14))
                        .foregroundStyle(.green.opacity(0.7))
                        .monospaced()
                        .padding(2)
                        .background {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(.black)
                        }
                } else {
                    Text("Not specified").foregroundStyle(.tertiary)
                }
            }
            .frame(width: 180, alignment: .leading)
        } label: {
            HStack {
                Image(systemName: icon)
                    .symbolRenderingMode(.multicolor)
                    .foregroundStyle(color)
                Text(title)
            }
        }
    }
    
    @ViewBuilder
    private var computedView: some View {
        if let computed = viewModel.computed {
            VStack {
                importRow("Prediction", "wand.and.sparkles", color: .yellow, data: computed.lifeExpectancy)
                let url = Storage.url(for: .encryptedOutput)
                PrivateText(url: url)
            }
        }
    }
    
    // MARK: - ACTIONS -
    private func importData() async {
        try? await Task.sleep(for: .seconds(1))
        if let encryptedData = try? await Storage.read(.encryptedInput) {
            viewModel.imported = .init(age: encryptedData,
                                       sex: encryptedData,
                                       bloodType: encryptedData,
                                       weightHistory: encryptedData,
                                       sleepHistory: encryptedData,
                                       heartRateHistory: encryptedData
            )
        }
    }

    private func upload() async {
        try? await Task.sleep(for: .seconds(1))
    }
    
    private func reloadFromDisk() async {
        try? await Task.sleep(for: .seconds(0.5))
        
        if let computed = try? await Storage.read(.encryptedOutput) {
            viewModel.computed = .init(lifeExpectancy: computed,
                                       heartStat: .init(min: computed,
                                                        max: computed,
                                                        average: computed))
        }
    }

    private func reset() {
        viewModel.imported = nil
        viewModel.computed = nil
    }
}

#Preview {
    AnalysisView()
}

@main
struct ClientApp: App {
    var body: some Scene {
        WindowGroup {
            AnalysisView()
        }
    }
}

