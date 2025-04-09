// Copyright © 2025 Zama. All rights reserved.

import SwiftUI

#Preview {
    @Previewable @State var tab = DataVaultTab.home
    TabView(selection: $tab) {
        Tab("Home", systemImage: "house", value: .home) {
            HomeTab(selectedTab: $tab)
        }
    }
}

struct HomeTab: View {
    @Binding var selectedTab: DataVaultTab
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("ZAMA\nDATA\nVAULT")
                    .multilineTextAlignment(.leading)
                    .font(.custom("Telegraf-Bold", size: 50))
                    .padding(.bottom, 20)
                
                Text("What sensitive data would you like to protect?")
                    .customFont(.title2)
                
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Button("Sleep") {
                            selectedTab = .sleep
                        }
                        Button("Weight") {
                            selectedTab = .weight
                        }
                    }
                    Button("Profile Information") {
                        selectedTab = .profile
                    }
                }
                .buttonStyle(.zama)
                
                Text("How does it work behind the scenes?")
                    .customFont(.title2)
                
                Text("Fully Homomorphic Encryption (FHE) lets you process your data while keeping it encrypted, ensuring your privacy at all times.")
                
                Image(.fheTutorial)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                
                Link("Learn More on Zama.ai", destination: ZamaConfig.websiteFHEIntro)
                    .buttonStyle(.zama)
                
                Spacer()
            }
            .padding(.horizontal, 30)
            
            .customFont(.body)
        }
    }
}
