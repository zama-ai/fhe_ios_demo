// Copyright © 2025 Zama. All rights reserved.

import SwiftUI

#Preview {
    SleepTab()
}

struct SleepTab: View {
    @StateObject var vm = ViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if vm.samplesAvailable {
                    AsyncButton("Select Encrypted Data") {
                        vm.selectSample()
                    }
                } else {
                    OpenAppButton(.zamaDataVault(tab: .sleep)) {
                        Text("Import Encrypted Data")
                    }
                }

                CustomBox("Sleep Phase") {
                    if let url = vm.sampleSelected {
                        FilePreview(url: url)
                            .frame(height: 160)
                        
                        Text("""
                            **Awake**: Often brief and unnoticed.
                            **REM**: Dreaming stage, crucial for memory and emotions.
                            **Core**: Light sleep, prepares the body for deeper stages.
                            **Deep**: Restorative sleep, vital for physical recovery and growth.
                            """)

                    } else {
                        NoDataBadge()
                    }
                }
                
                CustomBox("Sleep Quality") {
                    NoDataBadge()
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Sleep Analysis")
            .buttonStyle(.custom)
            .background(Color.zamaYellowLight)
            .onAppearAgain {
                vm.refreshFromDisk()
            }
        }
    }
}

extension SleepTab {
    @MainActor final class ViewModel: ObservableObject {
        @Published var samplesAvailable: Bool
        @Published var sampleSelected: URL?
                
        init() {
            self.samplesAvailable = false
            self.sampleSelected = nil
        }
        
        func refreshFromDisk() {
            Task {
                let foundSamples = await Storage.read(.sleepList)
                self.samplesAvailable = foundSamples != nil
                // TODO: ensure current selection is present in samplesAvailable
            }
        }
        
        func selectSample() {
            self.sampleSelected = Storage.url(for: .sleepList)
        }
    }
}
