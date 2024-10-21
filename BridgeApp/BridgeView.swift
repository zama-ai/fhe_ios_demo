// Copyright © 2024 Zama. All rights reserved.

import SwiftUI
import Charts
import HealthKitUI

struct BridgeView: View {
    @State private var showHealthKitSheet = false
    @StateObject var viewModel = BridgeViewModel.shared
    
    var body: some View {
        header
        
        importButton
        
        List {
            VStack {
                chartRow("Weight", icon: "figure", color: .purple, values: viewModel.clearData.weight.map { Int($0) })
                sourceCode("kg", viewModel.clearData.weight)
                encryptedFileRow("weight.fheencrypted",
                                 data: viewModel.encryptedWeight,
                                 encrypt: viewModel.encryptWeight,
                                 delete: viewModel.deleteWeight
                )
            }
            
            VStack {
                chartRow("Sleep", icon: "bed.double.fill", color: .mint, values: viewModel.clearData.sleep)
                sourceCode("sleep level", viewModel.clearData.sleep)
                encryptedFileRow("sleep.fheencrypted", data: nil, encrypt: {}, delete: {})
            }
        }
        .listRowSpacing(20)
        .buttonStyle(.bordered)
        .task {
            try? await viewModel.loadFromDisk()
        }
    }
    
    @ViewBuilder
    private func encryptedFileRow(_ title: String,
                                  data: Data?,
                                  encrypt: @escaping @MainActor () async throws -> Void,
                                  delete: @escaping @MainActor () async throws -> Void) -> some View {
        if let data {
            HStack {
                Image(systemName: "document.fill")
                Text(title)
                Text(data.formattedSize).foregroundStyle(.secondary)
                Spacer()
                AsyncButton(action: delete) {
                    Image(systemName: "trash")
                }.tint(.red)
            }
            .padding(.vertical, 8)
        } else {
            AsyncButton(action: encrypt) {
                Text("Encrypt")
                    .frame(width: 150, alignment: .center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }
    
    @ViewBuilder
    private var header: some View {
        VStack {
            Text("Bridge")
                .bold()
                .font(.largeTitle)
                .foregroundColor(.yellow)
            
            Text("All Information in Clear")
                .bold()
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 24)
    }
    
    private var importButton: some View {
        AsyncButton(action: {
            showHealthKitSheet = true
        }, label: {
            Label("Import Health Information", systemImage: "heart.text.clipboard")
                .symbolRenderingMode(.multicolor)
                .font(.subheadline)
        })
        .buttonStyle(.bordered)
        .tint(.accentColor)
        .healthDataAccessRequest(store: viewModel.healthStore,
                                 readTypes: viewModel.sampleTypes,
                                 trigger: showHealthKitSheet) { result in
            Task { @MainActor in
                switch result {
                case .success:
                    viewModel.fetchHealthData()
                    
                case .failure(let failure):
                    print("failure", failure)
                }
            }
        }.task {
            Task {
                if try await viewModel.isAllowed() {
                    viewModel.fetchHealthData()
                }
            }
        }
    }
    
    @ViewBuilder
    private func chartRow(_ title: String, icon: String, color: Color, values: [Int]) -> some View {
        HStack {
                Text("\(Image(systemName: icon)) \(title)")
                    .foregroundStyle(color)
                    .symbolRenderingMode(.multicolor)
                    .font(.title2)
            Spacer()
            chart(values: values)
        }
        Divider()
    }
    
    private func chart(values: [Int]) -> some View {
        Chart {
            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                BarMark(
                    x: .value("Index", index),
                    y: .value("Value", value)
                )
            }
        }
        .foregroundStyle(.secondary.opacity(0.5))
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(width: 150, height: 50, alignment: .leading)
    }
    
    private func sourceCode(_ prefix: String, _ values: [Double]) -> some View {
        sourceCode("[\(values.map{ $0.formatted(.number.precision(.fractionLength(1))) }.joined(separator: " "))](\(prefix))")
    }

    private func sourceCode(_ prefix: String, _ values: [Int]) -> some View {
        sourceCode("[\(values.map{ "\($0)" }.joined(separator: " "))](\(prefix))")
    }

    private func sourceCode(_ code: String) -> some View {
        Text(code)
            .monospaced()
            .font(.system(size: 13))
            .padding(4)
            .foregroundStyle(.green)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.black)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

#Preview {
    BridgeView(viewModel: .shared)
}
