// Copyright © 2024 Zama. All rights reserved.

import SwiftUI
import Charts
import HealthKitUI

typealias UnitValue = (amount: String, unit: String?)

struct HealthView: View {
    @State private var selectedRow: String?
    @State private var selectedSamples: [Int]?
    @State private var encryptedSamples: [Int]?
    @State private var showHealthKitPermissions = false
    @StateObject var viewModel = HealthViewModel.shared
    
    var body: some View {
        Text("My Health History")
            .font(.largeTitle)
        
        AsyncButton("Read HealthKit") {
            try? await Task.sleep(for: .seconds(0.5))
            showHealthKitPermissions = true
        }
        .buttonStyle(.bordered)
        .healthDataAccessRequest(store: viewModel.healthStore,
                                  readTypes: viewModel.permissions,
                                  trigger: showHealthKitPermissions) { result in
            switch result {
            case .success(let success):
                print("success", success)
                viewModel.fetchHealthData()
                
            case .failure(let failure):
                print("failure", failure)
            }
        }
                
        AsyncButton("Encrypt Health Information") {
            let ck: ClientKey = try await {
                let saved = try? await ClientKey.readFromDisk()
                let new = try ClientKey.generate()
                return saved ?? new
            }()
            
            let sk: CompressedServerKey = try await {
                let saved = try? await CompressedServerKey.readFromDisk()
                let new = try CompressedServerKey(clientKey: ck)
                return saved ?? new
            }()
            
            try await ck.writeToDisk()
            try await sk.writeToDisk()
            
            let data = try FHEUInt16(encrypting: 22, clientKey: ck).toData()
            try await Storage.write(.encryptedInput, data: data)
        }
        .buttonStyle(.bordered)
                
        List {
            Section("Personal info") {
                infoRow
            }
            
            Section("Select data to encrypt") {
                row("Weight", unit: "kg", icon: "figure", color: .purple, values: viewModel.data.bodyMass)
                row("Heart rate", unit: "BPM", icon: "heart.fill", color: .pink, values: viewModel.data.heartRate)
                row("Sleep", unit: "h", icon: "bed.double.fill", color: .mint, values: viewModel.data.sleep)
                row("Energy Burned", unit: "kcal", icon: "flame.fill", color: .orange, values: viewModel.data.energyBurned)
                row("Exercice", unit: "min", icon: "flame.fill", color: .orange, values: viewModel.data.exercice)
            }
            
            encryptionSection
        }
        .listRowSpacing(4)
        .buttonStyle(.bordered).tint(.yellow)
    }
        
    @ViewBuilder
    private var encryptionSection: some View {
        if let selectedSamples {
            Section("Encryption") {
                GroupBox("Clear") {
                    sourceCode("\(selectedSamples)")
                }
                .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                .overlay(alignment: .topTrailing) {
                    Button("FHE Encrypt") {
                        print("encrypted")
                    }
                    .padding(6)
                    .disabled(selectedSamples.isEmpty != false)
                }
                
                GroupBox("Encrypted") {
                    let text = encryptedSamples.map({ "\($0)" }) ?? "-"
                    sourceCode(text)
                }
                .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
            }
        } else {
            EmptyView()
        }
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
    
    private var infoRow: some View {
        HStack(spacing: 4) {
            infoCell("Sex", value: viewModel.data.sex ?? "-")
            infoCell("Age", value: viewModel.data.age.map({ "\($0) yo" }) ?? "-")
            infoCell("Blood", value: viewModel.data.blood ?? "-")
            infoCell("Wheelchair", value: viewModel.data.wheelChair.map({ $0 ? "Yes" : "No" })  ?? "-")
        }
        .padding(4)
        .listRowBackground(EmptyView())
        .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
    }
    
    private func infoCell(_ title: String, value: String) -> some View {
        VStack {
            Text(title)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
                .font(.system(size: 11).bold())
            Text(value).font(.body)
        }
        .padding(4)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private func row(_ title: String, unit: String, icon: String, color: Color, values: [Int] = []) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text("\(Image(systemName: icon)) \(title)")
                    .foregroundStyle(color)
                    .font(.title2)
                
                let text = values.last.map({ "\($0)" }) ?? "  "
                unitDisplay(UnitValue(amount: text, unit: unit))
            }
            Spacer()
            chart(values: values, selected: selectedRow == title)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selectedRow = title
            selectedSamples = values
        }
        .listRowBackground(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(selectedRow == title ? Color.yellow : Color.secondary.opacity(0.5), lineWidth: 2)
        )
    }
    
    private func unitDisplay(_ value: UnitValue) -> some View {
        HStack(alignment: .bottom, spacing: 2) {
            Text(value.amount).font(.title).offset(y: 4)
            if let unit = value.unit {
                Text(unit).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
    
    @ViewBuilder
    private func chart(values: [Int], selected: Bool) -> some View {
        Chart {
            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                BarMark(
                    x: .value("Index", index),
                    y: .value("Value", value)
                )
            }
        }
        
        .foregroundStyle(selected ? .yellow : .secondary.opacity(0.5))
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(width: 100, height: 50, alignment: .leading)
    }
}

#Preview {
    HealthView()
}
