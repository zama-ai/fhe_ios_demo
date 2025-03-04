// Copyright © 2025 Zama. All rights reserved.

import SwiftUI

#Preview {
    WeightTab()
}

struct WeightTab: View {
    @StateObject var vm = ViewModel()
    @Environment(\.scenePhase) var scenePhase

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if vm.samplesAvailable {
                    AsyncButton("Select Encrypted Data") {
                        vm.selectSample()
                    }
                } else {
                    OpenAppButton(.zamaDataVault(tab: .weight)) {
                        Text("Import Encrypted Data")
                    }
                }

                CustomBox("Trend") {
                    if let url = vm.sampleSelected {
                        FilePreview(url: url)
                    } else {
                        Text("No data found")
                    }
                }
                
                CustomBox("Statistics") {
                    Text("No data found")
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Weight Analysis")
            .buttonStyle(.custom)
            .background(Color.zamaYellowLight)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                vm.onAppActive()
            }
        }
    }
}

extension WeightTab {
    @MainActor final class ViewModel: ObservableObject {
        @Published var samplesAvailable: Bool
        @Published var sampleSelected: URL?
                
        init() {
            self.samplesAvailable = false
            self.sampleSelected = nil
        }
        
        func onAppActive() {
            Task {
                let foundSamples = await Storage.read(.weightList)
                self.samplesAvailable = foundSamples != nil
                self.sampleSelected = nil
            }
        }
        
        func selectSample() {
            self.sampleSelected = Storage.url(for: .weightList)
        }
    }
}
