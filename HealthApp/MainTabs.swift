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
    }
}

struct HomeTab: View {
    @Binding var selectedTab: HealthTab

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                metricSection(.sleep) {
                    Text("No data found")
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                }
                
                metricSection(.weight) {
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
    
    private func metricSection<Content: View>(_ metric: Metric, @ViewBuilder content: @escaping () -> Content) -> some View {
        CustomBox(label: { Label(metric.displayInfo.name, systemImage: metric.displayInfo.icon) },
                  content: { content() },
                  onTap: { selectedTab = HealthTab(metric: metric) })
    }
}

enum HealthTab {
    case home, sleep, weight
    
    var displayInfo: (name: String, icon: String) {
        switch self {
        case .home: ("Home", "house")
        case .sleep: Metric.sleep.displayInfo
        case .weight: Metric.weight.displayInfo
        }
    }
    
    init(metric: Metric) {
        switch metric {
        case .sleep: self = .sleep
        case .weight: self = .weight
        }
    }
}

enum Metric {
    case sleep, weight
    
    var displayInfo: (name: String, icon: String) {
        switch self {
        case .sleep: ("Sleep", "bed.double.fill")
        case .weight: ("Weight", "scalemass.fill")
        }
    }
}
