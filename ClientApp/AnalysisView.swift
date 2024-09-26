// Copyright © 2024 Zama. All rights reserved.

import SwiftUI

struct AnalysisView: View {
    @State private var isAnimatingTitle = false
    @StateObject private var viewModel: ViewModel
    
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
            
            AsyncButton("Compute Analysis") {
                await computeAnalysis()
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
            PrivateText(data: computed.lifeExpectancy)
        }
    }
    
    // MARK: - ACTIONS -
    private func importData() async {
        try? await Task.sleep(for: .seconds(1))
        viewModel.imported = ViewModel.fake.imported
    }

    private func computeAnalysis() async {
        try? await Task.sleep(for: .seconds(1))
        viewModel.computed = ViewModel.fake.computed
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

