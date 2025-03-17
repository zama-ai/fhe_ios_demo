// Copyright © 2025 Zama. All rights reserved.

import SwiftUI

#Preview {
    HealthRoot()
}

struct HealthRoot: View {
    @State private var selectedTab: HealthTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house", value: .home) {
                HomeTab(selectedTab: $selectedTab)
                    .toolbarBackground(Color.zamaGreyBackground, for: .tabBar)
                    .toolbarBackground(.visible, for: .tabBar)
            }
            
            Tab("Sleep", systemImage: "bed.double", value: .sleep) {
                SleepTab()
                    .toolbarBackground(Color.zamaGreyBackground, for: .tabBar)
                    .toolbarBackground(.visible, for: .tabBar)
            }

            Tab("Weight", systemImage: "scalemass", value: .weight) {
                WeightTab()
                    .toolbarBackground(Color.zamaGreyBackground, for: .tabBar)
                    .toolbarBackground(.visible, for: .tabBar)
            }
        }
        .tint(.zamaOrange)
        .overlay(alignment: .topTrailing) {
            ZamaLink()
        }
    }
}
