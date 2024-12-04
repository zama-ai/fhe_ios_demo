// Copyright © 2024 Zama. All rights reserved.

import SwiftUI

#Preview {
    DataVaultView()
}

struct DataVaultView: View {
    @StateObject private var vm = ViewModel()
    @State private var showOtherAppInstallAlert = false
    
    struct Metric: Equatable {
        let name: String
        let icon: String
        let color: Color
        
        static let sleep: Metric = .init(name: "Sleep", icon: "bed.double.fill", color: .mint)
        static let weight: Metric = .init(name: "Weight", icon: "figure", color: .purple)
    }
    
    var body: some View {
        header
        
        content
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle)
            .tint(.orange)
            .task {
                try? await vm.loadFromDisk()
            }
    }
    
    private var header: some View {
        VStack(spacing: 0) {
            Text("Data Vault")
                .customFont(.largeTitle)
                .padding(.bottom)
            
            Text("Encrypt your health information using Fully Homomorphic Encryption (FHE), to protect it when using other apps requiring health data.\n Powered by Zama (learn more on **[zama.ai](https://zama.ai)**)")
                .customFont(.subheadline)
                .multilineTextAlignment(.center)
                .tint(.white)
        }.padding()
    }
    
    @ViewBuilder
    private var content: some View {
        ScrollView {
            section(for: .sleep,
                    granted: vm.sleepGranted,
                    items: vm.sleep,
                    file: vm.encryptedSleep,
                    subtitle: "Select Night",
                    encrypt: vm.encryptSleep,
                    delete: vm.deleteSleep)
            {
                let nights = vm.sleep.count == 1 ? "night" : "nights"
                Text("\(vm.sleep.count) \(nights) found")
                    .customFont(.title)
                
                Picker("", selection: $vm.selectedNight) {
                    ForEach(vm.sleep, id: \.date) { night in
                        let day = night.date.formatted(.dateTime.weekday().day())
                        let time = night.date.formatted(.dateTime.hour().minute())
                        Text("\(day) at \(time)").tag(night.date)
                    }
                }
                .buttonStyle(.bordered)
            }
            
            section(for: .weight,
                    granted: vm.weightGranted,
                    items: vm.weight,
                    file: vm.encryptedWeight,
                    subtitle: vm.weightDateRange,
                    encrypt: vm.encryptWeight,
                    delete: vm.deleteWeight)
            {
                Text("\(vm.weight.count) records found")
                    .customFont(.title)
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .padding(8)
    }
    
    @ViewBuilder
    private func section<Content: View, Element: Any>(for metric: Metric,
                                                      granted: Bool,
                                                      items: Array<Element>,
                                                      file: Data?,
                                                      subtitle: String,
                                                      encrypt: @escaping () async throws -> Void,
                                                      delete: @escaping () async throws -> Void,
                                                      @ViewBuilder content: () -> Content) -> some View {
        if !granted {
            permissionMissing(for: metric)
        } else if items.isEmpty {
            contentMissing(for: metric)
        } else {
            GroupBox {
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
                        
                        OpenOtherAppButton(appName: "FHE Health", appScheme: "fhehealthapp://", appID: nil, showAlert: $showOtherAppInstallAlert)
                            .customFont(.callout)
                            .foregroundStyle(.black)
                    }
                }
                .padding(.vertical)
            } label: {
                Label(metric.name, systemImage: metric.icon)
                    .imageScale(.large)
                    .symbolRenderingMode(.multicolor)
                    .foregroundStyle(metric.color)
                    .customFont(.title3)
                
                Divider()
            }
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
                Label {
                    Text("No \(metric.name) Data on Device")
                        .customFont(.title3)
                    
                } icon: {
                    Image(systemName: metric.icon)
                        .symbolRenderingMode(.multicolor)
                        .foregroundStyle(metric.color)
                }
            } description: {
                Text("Use Apple Health or another app to record your \(metric.name.lowercased()).")
                    .customFont(.callout)
                
                VStack(spacing: 10) {
                    Link("Open Apple Health", destination: URL(string: "x-apple-health://")!)
                        .foregroundStyle(.black)
                    
                    HStack {
                        VStack { Divider() }
                        Text(" or ")
                        VStack { Divider() }
                    }
                    
                    Button("Simulate \(metric.name) Data", action: metric == .sleep ? vm.useFakeSleep : vm.useFakeWeight)
                        .padding(.bottom, -20)
                        .foregroundStyle(.black)
                }
                .customFont(.callout)
            }
        }
    }
}
