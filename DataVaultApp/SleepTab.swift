// Copyright © 2025 Zama. All rights reserved.

import SwiftUI

//#Preview {
//    SleepTab(vm: .init())
//}

struct SleepTab: View {
    @ObservedObject var vm: HealthViewModel
        
    var body: some View {
        VStack(spacing: 0) {
            Label(DataVaultTab.sleep.displayInfo.name, systemImage: DataVaultTab.sleep.displayInfo.icon)
                .frame(maxWidth: .infinity, alignment: .leading)
                .customFont(.largeTitle)
                .padding(.horizontal, 30)
                .padding(.bottom, 30)
            
            ScrollView {
                VStack(spacing: 24) {
                    if vm.hasSleepFilesOnDisk == false {
                        let icon = Image(systemName: "exclamationmark.triangle.fill")
                        Text("\(icon)\nNo data found")
                            .customFont(.title3)
                            .multilineTextAlignment(.center)
                        
                        VStack(spacing: 10) {
                            if vm.sleepGranted {
                                AsyncButton("Refresh Apple Health", action: vm.requestSleepPermission)
                            } else {
                                AsyncButton("Allow Apple Health", action: vm.requestSleepPermission)
                            }
                            
                            Text("or")
                            
                            AsyncButton("Generate data sample", action: vm.generateFakeNights)
                        }
                    } else {
                        let icon2 = Image(systemName: "checkmark.circle.fill")
                        Text("\(icon2)\nYour data was successfully encrypted")
                            .customFont(.title3)
                            .multilineTextAlignment(.center)
                        
                        VStack(spacing: 10) {
                            OpenAppButton(.fheHealth(tab: .sleep))
                            
                            Text("or")
                            
                            if vm.sleepGranted {
                                AsyncButton("Refresh Apple Health", action: vm.requestSleepPermission)
                                    .buttonStyle(.zamaSecondary)
                            } else {
                                AsyncButton("Use Apple Health", action: vm.requestSleepPermission)
                                    .buttonStyle(.zamaSecondary)
                            }
                        }
                    }
                    
                    if !vm.sleepConsoleOutput.isEmpty || vm.hasSleepFilesOnDisk == false {
                        ConsoleSection(title: "FHE Encryption", output: vm.sleepConsoleOutput)
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
