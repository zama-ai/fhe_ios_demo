// Copyright © 2024 Zama. All rights reserved.

import SwiftUI

#Preview {
    DataVaultView()
}

struct DataVaultView: View {
    
    struct Metric: Equatable {
        let name: String
        let icon: String
        let color: Color
        
        static let profile: Metric = .init(name: "Profile", icon: "person.text.rectangle.fill", color: .teal)
        static let sleep: Metric = .init(name: "Sleep", icon: "bed.double.fill", color: .mint)
        static let weight: Metric = .init(name: "Weight", icon: "figure", color: .purple)
    }
    
    enum TabKind {
        case profile, sleep, weight
    }
    
    @StateObject private var vm = ViewModel()
    @State private var selectedTab: TabKind = .profile
    
    var body: some View {
        header
        
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
            
            Text("Encrypt your information using Fully Homomorphic Encryption (FHE), to protect it when using other apps requiring these data.\n Powered by Zama (learn more on **[zama.ai](https://zama.ai)**)")
                .customFont(.subheadline)
                .multilineTextAlignment(.center)
                .tint(.white)
        }.padding()
    }
    
    private var content: some View {
        ScrollView {
//        TabView(selection: $selectedTab) {
//            Tab(Metric.profile.name, systemImage: Metric.profile.icon, value: TabKind.profile) {
                profileSection
//            }
//            Tab(Metric.sleep.name, systemImage: Metric.sleep.icon, value: TabKind.sleep) {
                sleepSection
//            }
//            Tab(Metric.weight.name, systemImage: Metric.weight.icon, value: TabKind.weight) {
                weightSection
//            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .padding(8)
    }
    
    private var profileSection: some View {
        section(for: .profile,
                granted: true,
                items: [12],
                file: vm.encryptedProfile,
                subtitle: "Once encrypted, other apps can't access your information",
                encrypt: vm.encryptProfile,
                delete: vm.deleteProfile,
                openIn: .fheAdTargeting)
        {
            NavigationStack {
                ProfileForm(vm: vm)
            }
            .frame(height: 400)
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
                openIn: .fheHealth)
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
                openIn: .fheHealth)
        {
            Text("\(vm.weight.count) records found")
                .customFont(.title)
        }
    }
    
    @ViewBuilder
    private func section<Content: View, Element: Any>(for metric: Metric,
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
                permissionMissing(for: metric)
            } else if items.isEmpty {
                contentMissing(for: metric)
            } else {
                VStack {
                    content()
                    
                    if file == nil {
                        Text("\(subtitle)")
                            .customFont(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 24)
                        
                        AsyncButton("Encrypt \(metric.name)") {
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
                }
                .padding(.vertical)
            }
        } label: {
            Label(metric.name, systemImage: metric.icon)
                .imageScale(.large)
                .symbolRenderingMode(.multicolor)
                .foregroundStyle(metric.color)
                .customFont(.title3)
            
            Divider()
        }
    }
    
    private func permissionMissing(for metric: Metric) -> some View {
        GroupBox {
            ContentUnavailableView {
                Label {
                    Text("\(metric.name) Permission Needed")
                        .customFont(.title3)
                } icon: {
                    Image(systemName: metric.icon)
                        .symbolRenderingMode(.multicolor)
                        .foregroundStyle(metric.color)
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
                Text("Your \(metric.name.lowercased()) data will be FHE-encrypted for privacy-preserving use in other apps.")
                    .customFont(.callout)
                
            } actions: {
                AsyncButton(action: metric == .weight ? vm.requestWeightPermission : vm.requestSleepPermission) {
                    Text("Allow \(metric.name)")
                }
                .customFont(.callout)
                .foregroundStyle(.black)
            }
        }
    }
    
    private func contentMissing(for metric: Metric) -> some View {
        GroupBox {
            ContentUnavailableView {
                Text("No \(metric.name) Data on Device")
                    .customFont(.title3)
            } description: {
                Text("Use Apple Health or another app to record your \(metric.name.lowercased()).")
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
                    
                    if metric == .sleep {
                        Menu {
                            Button("Regular Sample", action: vm.useFakeSleep)
                            Button("Bad Sample", action: vm.useFakeBadSleep)
                            Button("Large Dataset (100 samples)", action: vm.useLargeFakeSleep)
                        } label: {
                            Text("Simulate \(metric.name) Data")
                                .foregroundStyle(.black)
                        }
                    } else {
                        Button("Simulate \(metric.name) Data", action: vm.useFakeWeight)
                            .foregroundStyle(.black)
                    }
                }
                .customFont(.callout)
                .padding(.bottom, -20)
            }
        }
    }
}
