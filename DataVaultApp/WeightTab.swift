// Copyright © 2025 Zama. All rights reserved.

import SwiftUI

#Preview {
    WeightTab(vm: .init())
}

struct WeightTab: View {
    @ObservedObject var vm: HealthViewModel
    private let tabType: DataVaultTab = .weight
    private let targetTab: HealthTab = .weight

    var body: some View {
        VStack(spacing: 34) {
            Label(tabType.displayInfo.name, systemImage: tabType.displayInfo.icon)
                .frame(maxWidth: .infinity, alignment: .leading)
                .customFont(.largeTitle)
            
            if vm.weightGranted && vm.encryptedWeight != nil {
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
                    AsyncButton("Allow Apple Health", action: vm.requestWeightPermission)
                    Text("or")
                    AsyncButton("Generate data sample", action: vm.useFakeWeight)
                }
            }
            
            VStack {
                Text("FHE Encryption")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .customFont(.title3)
                
                TextEditor(text: $vm.weightConsoleOutput)
                    .padding(8)
                    .scrollContentBackground(.hidden)
                    .background(Color.zamaGreyConsole)
            }
        }
        .buttonStyle(.zama)
        .customFont(.body)
        .padding(.horizontal, 30)
        .onAppearAgain {
            Task {
                try await vm.loadFromDisk()
            }
        }
    }
}
