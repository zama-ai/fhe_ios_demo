// Copyright © 2025 Zama. All rights reserved.

import SwiftUI

#Preview {
    DataVaultView()
}

struct DataVaultView: View {
        
    @StateObject private var vm = ViewModel()
    @State private var selectedTab: DataVaultTab = .sleep
    
    var body: some View {
        header
            .frame(maxWidth: .infinity)
            .overlay(alignment: .topTrailing) {
                ZamaLink()
            }
        
        content
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle)
            .tint(.orange)
            .task {
                do {
                    try await vm.loadFromDisk()
                } catch {
                    print("Error loading data: \(error)")
                }
            }
    }
    
    private var header: some View {
        VStack(spacing: 0) {
            Text("Data Vault")
                .customFont(.largeTitle)
                .padding(.bottom)            
        }.padding()
    }
    
    private var content: some View {
        TabView(selection: $selectedTab) {
            Tab(DataVaultTab.sleep.displayInfo.name, systemImage: DataVaultTab.sleep.displayInfo.icon, value: DataVaultTab.sleep) {
              sleepSection
            }
            Tab(DataVaultTab.weight.displayInfo.name, systemImage: DataVaultTab.weight.displayInfo.icon, value: DataVaultTab.weight) {
              weightSection
            }
            Tab(DataVaultTab.profile.displayInfo.name, systemImage: DataVaultTab.profile.displayInfo.icon, value: DataVaultTab.profile) {
              profileSection
            }
        }.onOpenURL { url in
            selectedTab = DataVaultTab(url: url) ?? .home
        }
    }
    
    private var profileSection: some View {
        GroupBox {
            ProfileForm()
                .frame(maxHeight: .infinity, alignment: .top)
        } label: {
            Label(DataVaultTab.profile.displayInfo.name, systemImage: DataVaultTab.profile.displayInfo.icon)
                .imageScale(.large)
                .symbolRenderingMode(.multicolor)
                .customFont(.title3)
            
            Divider()
        }
    }
    
    private var sleepSection: some View {
        section(for: .sleep,
                granted: vm.sleepGranted,
                items: vm.sleep,
                file: vm.encryptedSleep,
                subtitle: "Select Night",
                encrypt: vm.encryptSleep,
                delete: vm.deleteSleep,
                openIn: .fheHealth(tab: .sleep))
        {
            let nights = vm.sleep.count == 1 ? "night" : "nights"
            Text("\(vm.sleep.count) \(nights) found")
                .customFont(.title)
            
            Picker("", selection: $vm.selectedNight) {
                ForEach(vm.sleep, id: \.date) { night in
                    let day = night.date.formatted(.dateTime.weekday().day().month())
                    let time = night.date.formatted(.dateTime.hour().minute())
                    Text("\(day), begins at \(time)").tag(night.date)
                }
            }
            .buttonStyle(.bordered)
        }
    }
    
    private var weightSection: some View {
        section(for: .weight,
                granted: vm.weightGranted,
                items: vm.weight,
                file: vm.encryptedWeight,
                subtitle: vm.weightDateRange,
                encrypt: vm.encryptWeight,
                delete: vm.deleteWeight,
                openIn: .fheHealth(tab: .weight))
        {
            Text("\(vm.weight.count) records found")
                .customFont(.title)
        }
    }
    
    @ViewBuilder
    private func section<Content: View, Element: Any>(for tab: DataVaultTab,
                                                      granted: Bool,
                                                      items: Array<Element>,
                                                      file: Data?,
                                                      subtitle: String,
                                                      encrypt: @escaping () async throws -> Void,
                                                      delete: @escaping () async throws -> Void,
                                                      openIn clientApp: AppInfo,
                                                      @ViewBuilder content: () -> Content) -> some View {
        GroupBox {
            if !granted {
                permissionMissing(for: tab)
            } else if items.isEmpty {
                contentMissing(for: tab)
            } else {
                VStack {
                    content()
                    
                    if file == nil {
                        Text("\(subtitle)")
                            .customFont(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 24)
                        
                        AsyncButton("Encrypt \(tab.displayInfo.name)") {
                            try await encrypt()
                        }
                        .foregroundStyle(.black)
                    } else {
                        Text("\(Image(systemName: "checkmark.circle.fill")) Encrypted")
                            .customFont(.caption)
                            .foregroundStyle(.green)
                            .frame(maxWidth: .infinity)
                            .overlay(alignment: .trailing) {
                                AsyncButton(action: delete) {
                                    Image(systemName: "trash").imageScale(.small)
                                }.tint(.red)
                            }
                            .padding(.bottom, 24)
                        
                        OpenAppButton(clientApp)
                            .customFont(.callout)
                            .foregroundStyle(.black)
                    }
                    
                    Spacer()
                }
                .padding(.vertical)
            }
        } label: {
            Label(tab.displayInfo.name, systemImage: tab.displayInfo.icon)
                .imageScale(.large)
                .symbolRenderingMode(.multicolor)
                .customFont(.title3)
            
            Divider()
        }
    }
    
    private func permissionMissing(for tab: DataVaultTab) -> some View {
        GroupBox {
            ContentUnavailableView {
                Label {
                    Text("\(tab.displayInfo.name) Permission Needed")
                        .customFont(.title3)
                } icon: {
                    Image(systemName: tab.displayInfo.icon)
                        .symbolRenderingMode(.multicolor)
                        .overlay(alignment: .bottomTrailing) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .resizable()
                                .frame(width: 22, height: 22)
                                .foregroundStyle(.yellow)
                                .background(.black)
                                .clipShape(Circle().inset(by: 1))
                        }
                }
            } description: {
                Text("Your \(tab.displayInfo.name.lowercased()) data will be FHE-encrypted for privacy-preserving use in other apps.")
                    .customFont(.callout)
                
            } actions: {
                AsyncButton(action: tab == .weight ? vm.requestWeightPermission : vm.requestSleepPermission) {
                    Text("Allow \(tab.displayInfo.name)")
                }
                .customFont(.callout)
                .foregroundStyle(.black)
            }
        }
    }
    
    private func contentMissing(for tab: DataVaultTab) -> some View {
        GroupBox {
            ContentUnavailableView {
                Text("No \(tab.displayInfo.name) Data on Device")
                    .customFont(.title3)
            } description: {
                Text("Use Apple Health or another app to record your \(tab.displayInfo.name.lowercased()).")
                    .customFont(.callout)
                
                VStack(spacing: 10) {
                    OpenAppButton(.appleHealth)
                        .customFont(.callout)
                        .foregroundStyle(.black)
                    
                    HStack {
                        VStack { Divider() }
                        Text(" or ")
                        VStack { Divider() }
                    }
                    
                    if tab == .sleep {
                        Menu {
                            Button("Regular Sample", action: vm.useFakeSleep)
                            Button("Bad Sample", action: vm.useFakeBadSleep)
                            Button("Large Dataset (100 samples)", action: vm.useLargeFakeSleep)
                        } label: {
                            Text("Simulate \(tab.displayInfo.name) Data")
                                .foregroundStyle(.black)
                        }
                    } else {
                        Button("Simulate \(tab.displayInfo.name) Data", action: vm.useFakeWeight)
                            .foregroundStyle(.black)
                    }
                }
                .customFont(.callout)
                .padding(.bottom, -20)
            }
        }
    }
}
