// Copyright © 2025 Zama. All rights reserved.

import SwiftUI

#Preview {
    @Previewable @State var tab = HealthTab.home
    HomeTab(selectedTab: $tab)
}

struct HomeTab: View {
    @Binding var selectedTab: HealthTab
    @State private var sleepDate: Date?
    @State private var sleepInput: URL?
    @State private var sleepResult: URL?
    
    @State private var weightInterval: DateInterval?
    @State private var weightMin: URL?
    @State private var weightMax: URL?
    @State private var weightAvg: URL?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                customBox(goTo: .sleep) {
                    if sleepInput == nil && sleepResult == nil && sleepDate == nil {
                        NoDataBadge()
                    } else {
                        VStack(alignment: .leading, spacing: 20) {
                            if let sleepDate {
                                Text("\(sleepDate.formatted(date: .numeric, time: .omitted))")
                                    .customFont(.body)
                                    .bold()
                                    .foregroundStyle(Color.zamaYellow)
                            }
                            
                            if let sleepInput {
                                FilePreview(url: sleepInput)
                                    .frame(height: 40, alignment: .leading)
                            }
                            
                            if let sleepResult {
                                FilePreview(url: sleepResult)
                                    .frame(height: 40, alignment: .leading)
                            }
                        }
                    }
                }
                
                customBox(goTo: .weight) {
                    if weightAvg == nil && weightMax == nil && weightMin == nil && weightInterval == nil {
                        NoDataBadge()
                    } else {
                        VStack(alignment: .leading, spacing: 20) {
                            if let weightInterval {
                                Text("\(weightInterval.start.formatted(date: .numeric, time: .omitted)) - \(weightInterval.end.formatted(date: .numeric, time: .omitted))")
                                    .customFont(.body)
                                    .bold()
                                    .foregroundStyle(Color.zamaYellow)
                            }
                            
                            if let weightMin {
                                HStack(alignment: .top) {
                                    Text("Min: ")
                                    FilePreview(url: weightMin)
                                        .frame(width: 60, height: 40)
                                        .offset(y: -2)
                                    Text(" kg")
                                }
                            }
                            
                            if let weightMax {
                                HStack(alignment: .top) {
                                    Text("Max: ")
                                    FilePreview(url: weightMax)
                                        .frame(width: 60, height: 40)
                                        .offset(y: -2)
                                    Text(" kg")
                                }
                            }
                            
                            if let weightAvg {
                                HStack(alignment: .top) {
                                    Text("Avg: ")
                                    FilePreview(url: weightAvg)
                                        .frame(width: 60, height: 40)
                                        .offset(y: -2)
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
                // Hack to force QL Preview to reload…
                self.sleepInput = nil
                self.sleepResult = nil
                try? await Task.sleep(for: .seconds(0.01))

                // Sleep
                sleepDate = Constants.selectedNight
                sleepInput = Constants.selectedNightInputPreviewURL
                sleepResult = Constants.selectedNightResultPreviewURL
                                
                // Weight
                if let weightListURL = try Storage.listEncryptedFiles(matching: .weightList).first,
                   let interval = Storage.dateInterval(from: weightListURL.lastPathComponent) {
                    weightInterval = interval
                } else {
                    weightInterval = nil
                }
                
                let weightMinURL = Storage.url(for: .weightMin, suffix: "preview")
                let weightMaxURL = Storage.url(for: .weightMax, suffix: "preview")
                let weightAvgURL = Storage.url(for: .weightAvg, suffix: "preview")
                
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
