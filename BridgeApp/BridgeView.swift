// Copyright © 2024 Zama. All rights reserved.

import SwiftUI
import Charts
import HealthKitUI

struct BridgeView: View {
    @State private var showHealthKitSheet = false
    @State private var selectedNight: Date?
    @StateObject var viewModel = BridgeViewModel.shared
    
    var body: some View {
        header
                
        if viewModel.clearData.weight.isEmpty && viewModel.clearData.sleep.isEmpty {
            noContent
        } else {
            topRow
            someContent
        }
    }
    
    var topRow: some View {
        HStack {
            importButton
            openAppButton
        }
        .buttonStyle(.bordered)
        .tint(.accentColor)
        .padding(.top, 8)
        .padding(.bottom, -8)
    }

    var someContent: some View {
        List {
            let nights = viewModel.clearData.sleep
            if !nights.isEmpty {
                VStack {
                    HStack {
                        sectionHeader("Sleep", icon: "bed.double.fill", color: .mint)
                        Spacer()
                        Picker("", selection: $selectedNight) {
                            ForEach(nights, id: \.date) { night in
                                Text("\(night.date.formatted(.dateTime.weekday().day().month()))").tag(night.date)
                            }
                        }
                    }
                    .onChange(of: viewModel.clearData.sleep) { oldValue, newValue in
                        selectedNight = newValue.last?.date
                    }
                    
                    Divider()
                    
                    SleepChartView(samples: nights.last!.samples)
                    
                    encryptedFileRow(Storage.File.sleepList.rawValue,
                                     data: viewModel.encryptedSleep,
                                     encrypt: viewModel.encryptSleep,
                                     delete: viewModel.deleteSleep)
                }
            }
            
            VStack {
                HStack {
                    sectionHeader("Weight", icon: "figure", color: .purple)
                    Spacer()
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
            }
        }
        .listRowSpacing(20)
        .buttonStyle(.bordered)
        .task {
            try? await viewModel.loadFromDisk()
        }
    }
    
    var noContent: some View {
        List {
            ContentUnavailableView {
                Label("No Health Records", systemImage: "heart.text.clipboard")
                    .symbolRenderingMode(.multicolor)
            } description: {
                Text("Give the app permission to access Sleep and Weight to perform analysis on your data.")
            } actions: {
                importButton
                    .buttonStyle(.bordered)
                    .tint(.accentColor)
            }
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
            HStack {
                Image(systemName: "heart.text.clipboard")
                    .symbolRenderingMode(.multicolor)
                    .imageScale(.medium)
                Text("Read Sleep & Weight")
            }.font(.body)
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
    
    private func sectionHeader(_ title: String, icon: String, color: Color) -> some View {
        Text("\(Image(systemName: icon)) \(title)")
            .foregroundStyle(color)
            .symbolRenderingMode(.multicolor)
            .font(.title2)
            .frame(height: 50, alignment: .leading)
    }
    
    @ViewBuilder
    private func chart(values: [Int]) -> some View {
        let items = {
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
}

#Preview {
    BridgeView(viewModel: .shared)
}
