// Copyright © 2025 Zama. All rights reserved.

import SwiftUI

#Preview {
    MainTabs()
}

struct MainTabs: View {
    @State private var selectedTab: HealthTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house", value: .home) {
                HomeTab(selectedTab: $selectedTab)
                    .toolbarBackground(.zamaBackgroundTab, for: .tabBar)
                    .toolbarBackground(.visible, for: .tabBar)
            }
            
            Tab("Sleep", systemImage: "bed.double", value: .sleep) {
                SleepTab()
                    .toolbarBackground(.zamaBackgroundTab, for: .tabBar)
                    .toolbarBackground(.visible, for: .tabBar)
            }

            Tab("Weight", systemImage: "scalemass", value: .weight) {
                WeightTab()
                    .toolbarBackground(.zamaBackgroundTab, for: .tabBar)
                    .toolbarBackground(.visible, for: .tabBar)
            }
        }
        .tint(.zamaOrange)
        .overlay(alignment: .topTrailing) {
            ZamaLink()
        }
    }
}

struct HomeTab: View {
    @Binding var selectedTab: HealthTab

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                customBox(goTo: .sleep) {
                    Text("No data found")
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                }
                
                customBox(goTo: .weight) {
                    Text("2025/01/24")
                        .fontWeight(.semibold)
                        .foregroundStyle(.zamaYellow)
                    
                    Text("Min: **55** kg\nMax: **55** kg\nAverage: **55** kg")
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Health Report")
            .background(.zamaBackgroundPage) // Set new background
        }
    }
    
    private func customBox<Content: View>(goTo tab: HealthTab, @ViewBuilder content: @escaping () -> Content) -> some View {
        CustomBox(label: { Label(tab.displayInfo.name, systemImage: tab.displayInfo.icon) },
                  onTap: { selectedTab = tab },
                  content: { content() })
    }
}
