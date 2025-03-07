// Copyright © 2025 Zama. All rights reserved.

import SwiftUI

#Preview {
    WeightTab()
}

struct WeightTab: View {
    @StateObject var vm = ViewModel()

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
                    Group {
                        if let url = vm.selectedSample {
                            FilePreview(url: url)
                        } else {
                            NoDataBadge()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                CustomBox("Statistics") {
                    let list = zip(["Min", "Max", "Average"], [vm.result?.min, vm.result?.max, vm.result?.avg])
                    HStack(spacing: 16) {
                        ForEach(Array(list), id: \.0) { label, value in
                            statCell(url: value, name: label)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .overlay {
                        if vm.result == nil {
                            NoDataBadge()
                        }
                    }
                }
            }
            .padding()
            .navigationTitle("Weight Analysis")
            .buttonStyle(.custom)
            .background(Color.zamaYellowLight)
            .onAppearAgain {
                vm.refreshFromDisk()
            }
        }
    }

    private func statCell(url: URL?, name: String) -> some View {
        VStack(spacing: 12) {
            if let url {
                FilePreview(url: url)
                    .frame(maxHeight: .infinity)
            } else {
                Color.clear
                    .aspectRatio(contentMode: .fit)
                    .hidden()
            }
            Text(name)
                .customFont(.subheadline)
                .opacity(url == nil ? 0 : 1)
        }
    }
}

extension WeightTab {
    @MainActor final class ViewModel: ObservableObject {
        @Published var samplesAvailable: Bool
        @Published var selectedSample: URL?
        @Published var result: (min: URL, max: URL, avg: URL)?

        init() {
            self.samplesAvailable = false
            self.selectedSample = nil
        }
        
        func refreshFromDisk() {
            Task {
                let foundSamples = await Storage.read(.weightList)
                self.samplesAvailable = foundSamples != nil
                // TODO: ensure current selection is present in samplesAvailable
                
                if let _ = await Storage.read(.weightMin),
                   let _ = await Storage.read(.weightMax),
                   let _ = await Storage.read(.weightAvg)
                {
                    result = (min: Storage.url(for: .weightMin),
                              max: Storage.url(for: .weightMax),
                              avg: Storage.url(for: .weightAvg))
                }
            }
        }
        
        func selectSample() {
            self.selectedSample = Storage.url(for: .weightList)
            //let selectionMD5 = await Storage.read(.weightList)?.md5Identifier
        }
        
        private var selectionMD5: String? {
            get { return UserDefaults.standard.string(forKey: "selectionMD5") }
            set { UserDefaults.standard.set(newValue, forKey: "selectionMD5") }
        }
    }
}
