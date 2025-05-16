// Copyright © 2025 Zama. All rights reserved.

import SwiftUI

//#Preview {
//    SleepTab(vm: .init())
//}

struct SleepTab: View {
    @ObservedObject var vm: HealthViewModel
    @State private var isSecondEncryptionInSession: Bool = false
    
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
                            if !vm.sleepGranted {
                                AsyncButton("Allow Apple Health", action: vm.requestSleepPermission)
                            }
                            
                            Text("or")
                            
                            AsyncButton("Generate data sample", action: vm.generateFakeNights)
                        }
                    } else {
                        let icon2 = Image(systemName: "checkmark.circle.fill")
                        let text = isSecondEncryptionInSession ? "Your data was successfully updated and reencrypted" : "Your data was successfully encrypted"
                        
                        Text("\(icon2)\n\(text)")
                            .customFont(.title3)
                            .multilineTextAlignment(.center)
                        
                        VStack(spacing: 10) {
                            OpenAppButton(.fheHealth(tab: .sleep))
                            
                            Text("or")
                            
                            if vm.sleepEncryptedUsingFakeData == true {
                                AsyncButton("Refresh Data Example", action: {
                                    isSecondEncryptionInSession = true
                                    try await vm.generateFakeNights()
                                })
                                    .buttonStyle(.zamaSecondary)
                            } else {
                                AsyncButton("Refresh Encrypted Data", action: {
                                    isSecondEncryptionInSession = true
                                    try await vm.requestSleepPermission()
                                })
                                    .buttonStyle(.zamaSecondary)
                            }
                        }
                    }
                    
                    if !vm.sleepConsoleOutput.isEmpty || vm.hasSleepFilesOnDisk == false {
                        ConsoleSection(title: "FHE Encryption", output: vm.sleepConsoleOutput)
                    }
                    
                    Divider()
                        .padding(.vertical)

                    VStack(spacing: 10) {
                        Text("FHE Key Management")
                            .customFont(.title3)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        AsyncButton("Refresh FHE Keys") {
                             await vm.refreshFHEServerKey()
                        }
                        .buttonStyle(.zamaSecondary)

                        Text("If a FHE friendly app (like FHE Health) reports issues, use this to ensure your local FHE keys (Client, Server, Public) are correctly generated and saved.")
                            .customFont(.caption)
                            .foregroundStyle(.gray)
                            .multilineTextAlignment(.leading)
                        
                        if !vm.keyManagementConsoleOutput.isEmpty {
                            Button("Clear Key Refresh Log") {
                                vm.keyManagementConsoleOutput = ""
                            }
                            .customFont(.caption)
                            .tint(.gray)
                        }
                    }
                    
                    if !vm.keyManagementConsoleOutput.isEmpty {
                        ConsoleSection(title: "Key Refresh Log", output: vm.keyManagementConsoleOutput)
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
