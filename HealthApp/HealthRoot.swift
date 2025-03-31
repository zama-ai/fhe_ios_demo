// Copyright © 2025 Zama. All rights reserved.

import SwiftUI

#Preview {
    HealthRoot()
}

struct HealthRoot: View {
    @State private var selectedTab: HealthTab = .home
    
    var body: some View {
        TabView(selection: $selectedTab) {
            tabItem(value: .home) {
                HomeTab(selectedTab: $selectedTab)
            }
            
            tabItem(value: .sleep) {
                SleepTab()
            }
            
            tabItem(value: .weight) {
                WeightTab()
            }
        }
        .tint(.zamaOrange)
        .overlay(alignment: .topTrailing) {
            ZamaLink()
        }
        .overlay(alignment: .topTrailing) {
            ZamaInfoButton()
        }
        .onOpenURL { url in
            selectedTab = HealthTab(url: url) ?? .home
        }
    }
    
    @TabContentBuilder<HealthTab>
    private func tabItem<Content: View>(value: HealthTab, @ViewBuilder content: () -> Content) -> some TabContent<HealthTab> {
        Tab(value.displayInfo.name, systemImage: value.displayInfo.icon, value: value) {
            content()
                .toolbarBackground(Color.zamaGreyBackground, for: .tabBar)
                .toolbarBackground(.visible, for: .tabBar)
        }
    }
}
