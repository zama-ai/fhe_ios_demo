// Copyright © 2025 Zama. All rights reserved.

import SwiftUI

#Preview {
    SleepTab()
}

struct SleepTab: View {
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
                    OpenAppButton(.zamaDataVault(tab: .sleep)) {
                        Text("Import Encrypted Data")
                    }
                }

                CustomBox("Sleep Phase") {
                    if let url = vm.sampleSelected {
                        FilePreview(url: url)
                        
                        Text("""
                            **Awake**: Often brief and unnoticed.
                            **REM**: Dreaming stage, crucial for memory and emotions.
                            **Core**: Light sleep, prepares the body for deeper stages.
                            **Deep**: Restorative sleep, vital for physical recovery and growth.
                            """)

                    } else {
                        Text("No data found")
                    }
                }
                
                CustomBox("Sleep Quality") {
                    Text("No data found")
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Sleep Analysis")
            .buttonStyle(.custom)
            .background(Color.zamaYellowLight)
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    vm.onAppActive()
                }
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
        
        func onAppActive() {
            Task {
                let foundSamples = await Storage.read(.sleepList)
                self.samplesAvailable = foundSamples != nil
                self.sampleSelected = nil
            }
        }
        
        func selectSample() {
            self.sampleSelected = Storage.url(for: .sleepList)
        }
    }
}
