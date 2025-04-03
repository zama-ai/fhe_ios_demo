// Copyright © 2025 Zama. All rights reserved.

import SwiftUI

//#Preview {
//    WeightTab(vm: .init())
//}

struct WeightTab: View {
    @ObservedObject var vm: HealthViewModel
        
    var body: some View {
        VStack(spacing: 0) {
            Label(DataVaultTab.weight.displayInfo.name, systemImage: DataVaultTab.weight.displayInfo.icon)
                .frame(maxWidth: .infinity, alignment: .leading)
                .customFont(.largeTitle)
                .padding(.horizontal, 30)
                .padding(.bottom, 30)
            
            ScrollView {
                VStack(spacing: 24) {
                    if vm.encryptedWeight == nil {
                        let icon = Image(systemName: "exclamationmark.triangle.fill")
                        Text("\(icon)\nNo data found")
                            .customFont(.title3)
                            .multilineTextAlignment(.center)
                        
                        VStack(spacing: 10) {
                            if vm.weightGranted {
                                AsyncButton("Refresh Apple Health", action: vm.requestWeightPermission)
                            } else {
                                AsyncButton("Allow Apple Health", action: vm.requestWeightPermission)
                            }

                            Text("or")
                            
                            AsyncButton("Generate data sample", action: vm.generateFakeWeights)
                        }
                    } else {
                        let icon2 = Image(systemName: "checkmark.circle.fill")
                        Text("\(icon2)\nYour data was successfully encrypted")
                            .customFont(.title3)
                            .multilineTextAlignment(.center)
                        
                        VStack(spacing: 10) {
                            OpenAppButton(.fheHealth(tab: .weight))

                            Text("or")

                            if vm.weightGranted {
                                AsyncButton("Refresh Apple Health", action: vm.requestWeightPermission)
                                    .buttonStyle(.zamaSecondary)
                            } else {
                                AsyncButton("Use Apple Health", action: vm.requestWeightPermission)
                                    .buttonStyle(.zamaSecondary)
                            }
                        }
                    }
                    
                    if !vm.weightConsoleOutput.isEmpty || vm.encryptedWeight == nil {
                        ConsoleSection(title: "FHE Encryption", output: vm.weightConsoleOutput)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 30)
            }
            .scrollDismissesKeyboard(.immediately)
            .scrollBounceBehavior(.basedOnSize)
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
