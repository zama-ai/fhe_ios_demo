// Copyright © 2024 Zama. All rights reserved.

import SwiftUI

#Preview {
    ClientView()
}

struct ClientView: View {
    @StateObject private var vm = ViewModel()
    @Environment(\.scenePhase) var scenePhase

    var body: some View {
        VStack {
            header
            ScrollView {
                section("Sleep", icon: "bed.double.fill", color: .mint, data: vm.sleepInput) { data in
                    sleepInput(data)
                    sleepAnalysis
                }
                
                section("Weight", icon: "figure", color: .purple, data: vm.weightInput) { data in
                    weightInput(data)
                    weightAnalysis
                }
            }
        }
        .background(.yellow)
        .buttonStyle(.borderedProminent)
        .tint(.orange)
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                Task {
                    try await vm.loadFromDisk()
                }
            case _: break
            }
        }
    }
    
    private var header: some View {
        VStack {
            Text("Client **FHE**alth")
                .font(.largeTitle)
            
            Text("All Information Encrypted and Private")
                .font(.subheadline).bold()
                .foregroundStyle(.secondary)
        }
    }
        
    // MARK: - SLEEP -
    private func sleepInput(_ data: Data) -> some View {
        GroupBox("Your Night") {
            SleepChartView(samples: Sleep.Night.fake.samples)
                //.privateDisplayRing()
            
            Text("""
                **Awake**: Occurs between sleep cycles, often brief and unnoticed.
                **REM**: Dreaming stage, crucial for memory and emotions.
                **Core**: Light sleep, prepares the body for deeper stages.
                **Deep**: Restorative sleep, vital for physical recovery and growth.
                """)
            .foregroundStyle(.secondary)
            .font(.caption2)
            .padding(.horizontal, -8)
        }
    }
    
    private var sleepAnalysis: some View {
        GroupBox("Sleep Quality") {
            if let _ = vm.sleepResultQuality {
                HStack(alignment: .top, spacing: 16) {
                    secureDisplay(.sleepScore)
                    
                    Text("Sleep quality is based on last night's sleep duration and stages (REM, Deep, Core). A score of 1 reflects excellent rest, while 5 indicates poor sleep quality.")
                        .font(.caption)
                        .opacity(0.9)
                }
            } else {
                uploadButton("Night", legend: "Be patient, analysis can take up to 60 seconds", action: vm.uploadSleep)
            }
        }
    }
        
    // MARK: - WEIGHT -
    private func weightInput(_ data: Data) -> some View {
        GroupBox("History") {
            secureDisplay(.weightList)
            
            Text("Weight in Kg, as recorded in Health App")
            .foregroundStyle(.secondary)
            .font(.caption2)
            .padding(.horizontal, -8)
        }
    }

    private var weightAnalysis: some View {
        GroupBox("Analysis") {
            if vm.weightResultAvg != nil,
               vm.weightResultMin != nil,
               vm.weightResultMax != nil {
                let list: [(title: String, file: Storage.File)] = [
                    ("Min", .weightMin), ("Max", .weightMax), ("Avg", .weightAvg)
                ]
                HStack(spacing: 0) {
                    ForEach(list, id: \.self.title) { item in
                        secureDisplay(item.file)
                            .overlay(alignment: .bottom) {
                                Text(item.title)
                                    .padding(.bottom, 16)
                            }
                    }
                }
                .padding(.top, -8)
                .padding(.horizontal, -16)
            } else {
                uploadButton("Weight", legend: "Analysis takes a few seconds", action: vm.uploadWeight)
            }
        }
    }

    // MARK: - GENERIC -
    private func section<Content: View>(_ name: String, icon: String, color: Color, data: Data?, @ViewBuilder content: (Data) -> Content) -> some View {
        GroupBox {
            if let data {
                content(data)
            } else {
                noContent(name, icon: icon, color: color)
                    .padding(16)
            }
        } label: {
            if data != nil {
                Label(name, systemImage: icon)
                    .imageScale(.large)
                    .symbolRenderingMode(.multicolor)
                    .foregroundStyle(color)
            }
        }
        .padding(8)
    }
    
    private func noContent(_ name: String, icon: String, color: Color) -> some View {
        ContentUnavailableView {
            Label {
                Text("No \(name.capitalized) Records")
            } icon: {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .symbolRenderingMode(.multicolor)
            }
        } description: {
            Text("Generate encrypted \(name.lowercased()) records\nusing Bridge App.")
        } actions: {
            Link("Open Bridge App", destination: URL(string: "bridgeapp://")!)
        }
    }
    
    private func uploadButton(_ name: String, legend: String? = nil, action: @escaping () async throws -> Void) -> some View {
        VStack {
            AsyncButton("Upload \(name.capitalized) for Analysis", action: action)

            if let legend {
                Text(legend)
                    .foregroundStyle(.secondary)
                    .font(.caption2)
            }
        }
        .padding()
    }

    func secureDisplay(_ file: Storage.File) -> some View {
        FilePreview(url: Storage.url(for: file))
            .frame(minHeight: 150)
            .overlay {
                Color.white.opacity(0.01) // Hack to allow scrolling from this view
            }
    }
}
