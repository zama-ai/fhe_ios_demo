// Copyright © 2025 Zama. All rights reserved.

import SwiftUI

//#Preview {
//    SleepTab(vm: .init())
//}

struct SleepTab: View {
    @ObservedObject var vm: HealthViewModel
    
    private let tab: DataVaultTab = .sleep
    private let openHealthAppTab: HealthTab = .sleep

    var body: some View {
        VStack(spacing: 0) {
            Label(tab.displayInfo.name, systemImage: tab.displayInfo.icon)
                .frame(maxWidth: .infinity, alignment: .leading)
                .customFont(.largeTitle)
                .padding(.horizontal, 30)
                .padding(.bottom, 30)
            
            ScrollView {
                VStack(spacing: 24) {
                    if vm.encryptedSleep != nil {
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
                            if !vm.sleepGranted {
                                AsyncButton("Allow Apple Health", action: vm.requestSleepPermission)
                                Text("or")
                            }
                            AsyncButton("Generate data sample", action: vm.generateFakeNights)
                        }
                    }
                    
                    ConsoleSection(title: "FHE Encryption", output: vm.sleepConsoleOutput)
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
