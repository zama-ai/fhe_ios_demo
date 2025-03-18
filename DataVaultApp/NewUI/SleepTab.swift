// Copyright © 2025 Zama. All rights reserved.

import SwiftUI

#Preview {
    SleepTab()
}

struct SleepTab: View {
    @StateObject private var vm = ViewModel()
    
    var body: some View {
        VStack(spacing: 34) {
            Label(DataVaultTab.sleep.displayInfo.name, systemImage: DataVaultTab.sleep.displayInfo.icon)
                .frame(maxWidth: .infinity, alignment: .leading)
                .customFont(.largeTitle)
            
            if vm.dataAvailable {
                let icon2 = Image(systemName: "checkmark.circle.fill")
                Text("\(icon2)\nYour data was successfully encrypted")
                    .customFont(.title3)
                    .multilineTextAlignment(.center)
                
                OpenAppButton(.fheHealth(tab: .sleep)) {
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
    }
}

extension SleepTab {
    @MainActor final class ViewModel: ObservableObject {
        @Published var dataAvailable: Bool
        @Published var consoleOutput: String
        
        init() {
            self.dataAvailable = false
            self.consoleOutput = "No data to encrypt."
            
            Task {
                await refreshFromDisk()
            }
        }
        
        func refreshFromDisk() async {
            let data = await Storage.read(.sleepList)
            self.dataAvailable = data != nil
        }
    }
}
