// Copyright © 2025 Zama. All rights reserved.

import SwiftUI

#Preview {
    @Previewable @State var tab = HealthTab.home
    HomeTab(selectedTab: $tab)
}

struct HomeTab: View {
    @Binding var selectedTab: HealthTab
    @State private var sleepInput: URL?
    @State private var sleepResult: URL?

    @State private var weightMin: URL?
    @State private var weightMax: URL?
    @State private var weightAvg: URL?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                customBox(goTo: .sleep) {
                    if sleepInput == nil && sleepResult == nil {
                        NoDataBadge()
                    } else {
                        VStack(alignment: .leading, spacing: 0) {
                            
                            if let sleepInput {
                                FilePreview(url: sleepInput)
                                    .frame(height: 30)
                            }
                            
                            if let sleepResult {
                                FilePreview(url: sleepResult)
                                    .frame(height: 30)
                            }
                        }
                    }
                }
                
                customBox(goTo: .weight) {
                    if weightAvg == nil && weightMax == nil && weightMin == nil{
                        NoDataBadge()
                    } else {
                        VStack(alignment: .leading, spacing: 0) {
                            
                            if let weightMin {
                                HStack {
                                    Text("Min: ")
                                    FilePreview(url: weightMin)
                                        .frame(width: 90, height: 30, alignment: .trailing)
                                    Text(" kg")
                                }
                            }
                            
                            if let weightMax {
                                HStack {
                                    Text("Max: ")
                                    FilePreview(url: weightMax)
                                        .frame(width: 80, height: 30, alignment: .trailing)
                                    Text(" kg")
                                }
                            }
                            
                            if let weightAvg {
                                HStack {
                                    Text("Avg: ")
                                    FilePreview(url: weightAvg)
                                        .frame(width: 70, height: 30, alignment: .trailing)
                                    Text(" kg")
                                }
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .fontWeight(.regular)
            .font(.custom("Telegraf-Bold", size: 22))
            .padding()
            .navigationTitle("Health Report")
            .background(Color.zamaYellowLight)
        }.onAppearAgain {
            Task {
                let sleepInputURL = Storage.url(for: .sleepList, suffix: "preview")
                let sleepResultURL = Storage.url(for: .sleepScore, suffix: "preview")

                let weightMinURL = Storage.url(for: .weightMin, suffix: "preview")
                let weightMaxURL = Storage.url(for: .weightMax, suffix: "preview")
                let weightAvgURL = Storage.url(for: .weightAvg, suffix: "preview")

                // Sleep
                if let _ = await Storage.read(sleepInputURL) {
                    sleepInput = sleepInputURL
                } else {
                    sleepInput = nil
                }

                if let _ = await Storage.read(sleepResultURL) {
                    sleepResult = sleepResultURL
                } else {
                    sleepResult = nil
                }

                // Weight
                if let _ = await Storage.read(weightMinURL) {
                    weightMin = weightMinURL
                } else {
                    weightMin = nil
                }
                
                if let _ = await Storage.read(weightMaxURL) {
                    weightMax = weightMaxURL
                } else {
                    weightMax = nil
                }

                if let _ = await Storage.read(weightAvgURL) {
                    weightAvg = weightAvgURL
                } else {
                    weightAvg = nil
                }
            }
        }
    }
    
    func formattedDuration(from timeInterval: TimeInterval) -> Text {
        let totalMinutes = Int(timeInterval) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        
        return Text("**\(hours.formatted())** Hours **\(minutes.formatted())** Minutes")
    }
    
    private func customBox<Content: View>(goTo tab: HealthTab, @ViewBuilder content: @escaping () -> Content) -> some View {
        CustomBox(label: { Label(tab.displayInfo.name, systemImage: tab.displayInfo.icon) },
                  onTap: { selectedTab = tab },
                  content: {
            content()
                .fontWeight(.regular)
                .frame(minHeight: 100, alignment: .top)
        })
    }
}
