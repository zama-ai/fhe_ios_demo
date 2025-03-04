// Copyright © 2025 Zama. All rights reserved.

import SwiftUI

#Preview {
    @Previewable @State var tab = HealthTab.home
    HomeTab(selectedTab: $tab)
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
            .background(Color.zamaYellowLight)
        }
    }
    
    private func customBox<Content: View>(goTo tab: HealthTab, @ViewBuilder content: @escaping () -> Content) -> some View {
        CustomBox(label: { Label(tab.displayInfo.name, systemImage: tab.displayInfo.icon) },
                  onTap: { selectedTab = tab },
                  content: { content() })
    }
}
