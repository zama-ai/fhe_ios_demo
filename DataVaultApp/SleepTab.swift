// Copyright © 2025 Zama. All rights reserved.

import SwiftUI

#Preview {
    SleepTab(vm: .init())
}

struct SleepTab: View {
    @ObservedObject var vm: HealthViewModel
    
    var body: some View {
        VStack(spacing: 34) {
            Label(DataVaultTab.sleep.displayInfo.name, systemImage: DataVaultTab.sleep.displayInfo.icon)
                .frame(maxWidth: .infinity, alignment: .leading)
                .customFont(.largeTitle)
            
            if vm.sleepGranted && vm.encryptedSleep != nil {
                let icon2 = Image(systemName: "checkmark.circle.fill")
                Text("\(icon2)\nYour data was successfully encrypted")
                    .customFont(.title3)
                    .multilineTextAlignment(.center)
                
                OpenAppButton(.fheHealth(tab: .sleep))
            } else {
                let icon = Image(systemName: "exclamationmark.triangle.fill")
                Text("\(icon)\nNo data found")
                    .customFont(.title3)
                    .multilineTextAlignment(.center)
                
                VStack(spacing: 10) {
                    AsyncButton("Allow Apple Health", action: vm.requestSleepPermission)
                    Text("or")
                    Menu {
                        AsyncButton("Regular Sample", action: { try await vm.encrypt(night: .fake) })
                        AsyncButton("Bad Sample", action: { try await vm.encrypt(night: .fakeBad) })
                        AsyncButton("Large Dataset (100 samples)", action: { try await vm.encrypt(night: .fakeLarge) })
                    } label: {
                        Text("Generate data sample")
                    }
                }
            }
            
            VStack {
                Text("FHE Encryption")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .customFont(.title3)
                
                TextEditor(text: $vm.sleepConsoleOutput)
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
