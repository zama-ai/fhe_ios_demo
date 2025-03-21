// Copyright © 2025 Zama. All rights reserved.

import SwiftUI

//#Preview {
//    WeightTab(vm: .init())
//}

struct WeightTab: View {
    @ObservedObject var vm: HealthViewModel

    private let tab: DataVaultTab = .weight
    private let openHealthAppTab: HealthTab = .weight

    var body: some View {
        VStack(spacing: 0) {
            Label(tab.displayInfo.name, systemImage: tab.displayInfo.icon)
                .frame(maxWidth: .infinity, alignment: .leading)
                .customFont(.largeTitle)
                .padding(.horizontal, 30)
                .padding(.bottom, 30)
            
            ScrollView {
                VStack(spacing: 24) {
                    if vm.weightGranted && vm.encryptedWeight != nil {
                        let icon2 = Image(systemName: "checkmark.circle.fill")
                        Text("\(icon2)\nYour data was successfully encrypted")
                            .customFont(.title3)
                            .multilineTextAlignment(.center)
                        
                        OpenAppButton(.fheHealth(tab: openHealthAppTab))
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
                    
                    ConsoleSection(title: "FHE Encryption", output: vm.weightConsoleOutput)
                    Spacer()
                }
                .padding(.horizontal, 30)
            }
            .scrollDismissesKeyboard(.immediately)
        }
        .customFont(.body)
        .buttonStyle(.zama)
        .onAppearAgain {
            Task {
                try await vm.loadFromDisk()
            }
        }
    }
}
