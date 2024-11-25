// Copyright © 2024 Zama. All rights reserved.

import SwiftUI

#Preview {
    BridgeView()
}

struct BridgeView: View {
    @StateObject private var vm = ViewModel()
    
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
        .buttonStyle(.bordered)
        .tint(.orange)
        .task {
            try? await vm.loadFromDisk()
        }
    }
    
    private var header: some View {
        VStack {
            Text("Bridge App")
                .font(.largeTitle)
                .padding(.bottom)
            
            Text("Encrypt health information using **[FHE](https://zama.ai)**, so that it can be consumed in a privacy-preserving way in other apps. Learn more at **[zama.ai](https://zama.ai)**")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
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
                Text("\(vm.sleep.count) nights found")
                    .font(.title)

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
                    .font(.title)
            }
        }.scrollBounceBehavior(.basedOnSize)
    }

    @ViewBuilder
    private func section<Content: View, Element: Any>(for metric: Metric,
                                                      granted: Bool = true,
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
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 24)
                        
                        AsyncButton("Encrypt \(metric.name)") {
                            try await encrypt()
                        }
                    } else {
                        Text("\(Image(systemName: "checkmark.circle.fill")) Encrypted")
                            .font(.caption)
                            .foregroundStyle(.green)
                            .frame(maxWidth: .infinity)
                            .overlay(alignment: .trailing) {
                                AsyncButton(action: delete) {
                                    Image(systemName: "trash").imageScale(.small)
                                }.tint(.red)
                            }
                            .padding(.bottom, 24)
                        
                        Link("View in FHE Health App", destination: URL(string: "fhehealthapp://")!)
                    }
                }
                .padding(.vertical)
            } label: {
                Label(metric.name, systemImage: metric.icon)
                    .imageScale(.large)
                    .symbolRenderingMode(.multicolor)
                    .foregroundStyle(metric.color)
                Divider()
            }
        }
    }
    
    private func permissionMissing(for metric: Metric) -> some View {
        GroupBox {
            ContentUnavailableView {
                Label {
                    Text("\(metric.name) Permission Needed")
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
                Text("Your \(metric.name.lowercased()) will be FHE-encrypted for privacy-preserving use in other apps.")
            } actions: {
                AsyncButton(action: metric == .weight ? vm.requestWeightPermission : vm.requestSleepPermission) {
                    Text("Allow \(metric.name)")
                }
            }
        }
    }
    
    private func contentMissing(for metric: Metric) -> some View {
        GroupBox {
            ContentUnavailableView {
                Label {
                    Text("No \(metric.name) Data on Device")
                } icon: {
                    Image(systemName: metric.icon)
                        .symbolRenderingMode(.multicolor)
                        .foregroundStyle(metric.color)
                }
            } description: {
                Text("Use Apple Health or another app to record your \(metric.name.lowercased()).")
                Link("Open Apple Health", destination: URL(string: "x-apple-health://")!)
            }
        }
    }
}
