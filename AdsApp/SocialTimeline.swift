// Copyright © 2025 Zama. All rights reserved.

import SwiftUI

#Preview {
    SocialTimeline()
}

struct SocialTimeline: View {
    @StateObject private var vm = ViewModel()
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) var scenePhase

    var body: some View {
        VStack {
            titleBar
                .padding(.top, 8)
            
            if vm.dataVaultActionNeeded {
                openDataVaultCard
            } else {
                ScrollView {
                    ForEach(vm.items) { item in
                        switch item {
                        case .post(let post): postView(post)
                        case .ad(let index): adView(at: index)
                        }
                    }
                    .padding(.horizontal, 8)
                }
            }
        }
        .background(.orange)
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                Task {
                    await vm.onAppear()
                }
            case _: break
            }
        }
    }
    
    private var openDataVaultCard: some View {
        GroupBox {
            ContentUnavailableView {
                Label("No Profile Info", systemImage: "person.crop.circle.badge.exclamationmark.fill")
                    .customFont(.title3)
            } description: {
                Text("Import encrypted profile info from Zama Data Vault.")
                    .customFont(.callout)
            } actions: {
                OpenAppButton(.fheDataVault)
                    .customFont(.callout)
                    .foregroundStyle(.black)
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.roundedRectangle)
            }
        }
        .padding()
    }
    
    private var titleBar: some View {
        VStack(spacing: 4) {
            Text("FHE Ads")
                .customFont(.largeTitle)
                .frame(maxWidth: .infinity)
                .overlay(alignment: .trailing) {
                    OpenAppButton(.fheDataVault) {
                        Label("Profile", systemImage: "person.crop.circle.fill")
                    }
                    .padding(6)
                    .buttonStyle(.bordered)
                    .tint(.black)
                }
            
            if let report = vm.activityReport {
                HStack(spacing: 2) {
                    switch report {
                    case .progress(let string):
                        Text(string)
                        ProgressView()
                            .scaleEffect(0.8)
                        
                    case .error(let string):
                        Text("⚠️ " + string)
                    }
                }
                .customFont(.footnote)
            }
        }
    }
    
    private func postView(_ post: Post) -> some View {
        GroupBox {
            HStack(alignment: .top) {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .frame(width: 32, height: 32)
                    .foregroundStyle([.yellow, .orange, .gray].randomElement()!)
                
                VStack(alignment: .leading) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(post.username)
                            .customFont(.headline)
                        
                        Text(post.handle)
                            .customFont(.subheadline)
                            .foregroundColor(.gray)
                        
                        Spacer()
                        
                        Text(post.timestamp)
                            .customFont(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding(.bottom, 2)
                    
                    Text(post.content)
                        .customFont(.callout)
                        .foregroundColor(.primary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    @ViewBuilder
    private func adView(at index: Int) -> some View {
        FilePreview(url: Storage.url(for: .concreteEncryptedResult, suffix: "\(index)"))
            .frame(minHeight: 175)
            .overlay {
                Color.white.opacity(0.01) // Hack to allow scrolling from this view
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(alignment: .bottomTrailing) {
                Text("Privately Targeted Ad")
                    .customFont(.subheadline)
                    .foregroundColor(.gray)
                    .padding(4)
            }
    }
}
