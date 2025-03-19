// Copyright © 2025 Zama. All rights reserved.

import SwiftUI

#Preview {
    WeightTab()
}

struct WeightTab: View {
    @StateObject private var vm = ViewModel()
    private let tabType: DataVaultTab = .weight
    private let targetTab: HealthTab = .weight

    var body: some View {
        VStack(spacing: 34) {
            Label(tabType.displayInfo.name, systemImage: tabType.displayInfo.icon)
                .frame(maxWidth: .infinity, alignment: .leading)
                .customFont(.largeTitle)
            
            if vm.dataAvailable {
                let icon2 = Image(systemName: "checkmark.circle.fill")
                Text("\(icon2)\nYour data was successfully encrypted")
                    .customFont(.title3)
                    .multilineTextAlignment(.center)
                
                OpenAppButton(.fheHealth(tab: targetTab)) {
                    Text("Analyze data on FHE Health")
                }
            } else {
                let icon = Image(systemName: "exclamationmark.triangle.fill")
                Text("\(icon)\nNo data found")
                    .customFont(.title3)
                    .multilineTextAlignment(.center)
                
                VStack(spacing: 10) {
                    Button("Allow Apple Health", action: {})
                    Text("or")
                    Button("Generate data sample", action: {})
                }
            }
            
            VStack {
                Text("FHE Encryption")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .customFont(.title3)
                
                TextEditor(text: $vm.consoleOutput)
                    .padding(8)
                    .scrollContentBackground(.hidden)
                    .background(Color.zamaGreyConsole)
            }
        }
        .buttonStyle(.zama)
        .customFont(.body)
        .padding(.horizontal, 30)
        .onAppearAgain {
            vm.refreshFromDisk()
        }
    }
}

import HealthKit

extension WeightTab {
    @MainActor final class ViewModel: ObservableObject {
        @Published var dataAvailable: Bool
        @Published var consoleOutput: String

        private let fileType: Storage.File = .weightList

        init() {
            self.dataAvailable = false
            self.consoleOutput = "No data to encrypt."
        }
        
        func refreshFromDisk() {
            Task {
                let data = await Storage.read(fileType)
                self.dataAvailable = data != nil
            }
        }
    }
}
