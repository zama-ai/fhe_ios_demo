// Copyright © 2024 Zama. All rights reserved.

import SwiftUI
import Charts
import HealthKitUI

struct BridgeView: View {
    @State private var showHealthKitSheet = false
    @StateObject var viewModel = BridgeViewModel.shared
    
    var body: some View {
        header
        
        HStack {
            importButton
            openAppButton
        }
        .buttonStyle(.bordered)
        .tint(.accentColor)
        .padding(.top, 8)
        .padding(.bottom, -8)

        List {
            VStack {
                HStack {
                    chartRow("Sleep", icon: "bed.double.fill", color: .mint, values: [])
                    Picker("", selection: .constant(1)) {
                        Text("\(Sleep.Night.fake.date.formatted(.dateTime.weekday().day().month()))").tag(1)
                        Text("Yesterday").tag(2)
                    }
                }
                
                Divider()
                SleepChartView(samples: Sleep.Night.fake.samples)
                encryptedFileRow(Storage.File.sleepList.rawValue,
                                 data: viewModel.encryptedSleep,
                                 encrypt: viewModel.encryptSleep,
                                 delete: viewModel.deleteSleep)
                //sourceCode(viewModel.clearData.sleep)
            }
            
            VStack {
                HStack {
                    chartRow("Weight", icon: "figure", color: .purple, values: [])
                    Text("\(viewModel.clearData.weight.last?.formatted(.number.precision(.fractionLength(1))) ?? "-") kg")
                        .foregroundStyle(.secondary)
                        .font(.title3)
                        .padding()
                }
                Divider().frame(maxWidth: .infinity)
                chart(values: viewModel.clearData.weight.map { Int($0) })
                encryptedFileRow(Storage.File.weightList.rawValue,
                                 data: viewModel.encryptedWeight,
                                 encrypt: viewModel.encryptWeight,
                                 delete: viewModel.deleteWeight
                )
                //sourceCode(viewModel.clearData.weight)
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
                }
                .tint(.red)
            }
            .font(.callout)
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
    }
    
    private var importButton: some View {
        AsyncButton(action: {
            showHealthKitSheet = true
        }, label: {
            Label("Import Health Info", systemImage: "heart.text.clipboard")
                .symbolRenderingMode(.multicolor)
        })
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
    
    private var openAppButton: some View {
        Button(action:{ }) {
            Link("Open Client App", destination: URL(string: "clientapp://")!)
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
            if !values.isEmpty {
                chart(values: values)
            }
        }
        .frame(height: 50)
    }
    
    @ViewBuilder
    private func chart(values: [Int]) -> some View {
        var items = {
            var values = values
            values.insert(0, at: 0)
            values.append(0)
            return values
        }()
        
        Chart {
            ForEach(Array(items.enumerated()), id: \.offset) { index, value in
                BarMark(
                    x: .value("Index", index),
                    y: .value("Value", value)
                )
            }
        }
        .foregroundStyle(.tint)
        .chartXAxis(.hidden)
        .frame(height: 70, alignment: .leading)
        .padding()
    }
    
    private func sourceCode(_ values: [Double]) -> some View {
        sourceCode("[\(values.map{ $0.formatted(.number.precision(.fractionLength(1))) }.joined(separator: " "))]")
    }
    
    private func sourceCode(_ values: [Int]) -> some View {
        sourceCode("[\(values.map{ "\($0)" }.joined(separator: " "))]")
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
