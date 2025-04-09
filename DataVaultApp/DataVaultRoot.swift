// Copyright © 2025 Zama. All rights reserved.

import SwiftUI

#Preview {
    DataVaultRoot()
}

struct DataVaultRoot: View {
    @State private var selectedTab: DataVaultTab = .home
    @StateObject private var healthVM = HealthViewModel()
    
    var body: some View {
        TabView(selection: $selectedTab) {
            tabItem(value: .home) {
                HomeTab(selectedTab: $selectedTab)
            }
            
            tabItem(value: .sleep) {
                SleepTab(vm: healthVM)
            }
            
            tabItem(value: .weight) {
                WeightTab(vm: healthVM)
            }
            
            tabItem(value: .profile) {
                ProfileTab()
            }
        }
        .padding(.top, 30)
        .tint(.zamaYellow)
        .overlay(alignment: .topTrailing) {
            ZamaLink()
        }
        .onOpenURL { url in
            selectedTab = DataVaultTab(url: url) ?? .home
        }
    }
    
    @TabContentBuilder<DataVaultTab>
    private func tabItem<Content: View>(value: DataVaultTab, @ViewBuilder content: () -> Content) -> some TabContent<DataVaultTab> {
        Tab(value.displayInfo.name, systemImage: value.displayInfo.icon, value: value) {
            content()
                .toolbarBackground(Color.zamaBlackTabBar, for: .tabBar)
                .toolbarBackground(.visible, for: .tabBar)
        }
    }
}
