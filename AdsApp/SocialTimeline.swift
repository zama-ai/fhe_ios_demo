// Copyright © 2025 Zama. All rights reserved.

import SwiftUI

#Preview {
    SocialTimeline()
}

struct SocialTimeline: View {
    @StateObject private var vm = ViewModel()
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        VStack {
            titleBar
                .padding(.top, 8)
            
            if vm.dataVaultActionNeeded {
                VStack(spacing: 40) {
                    let icon = Image(systemName: "exclamationmark.triangle.fill")
                    Text("\(icon)\n\nNo Profile found")
                        .customFont(.title3)
                        .multilineTextAlignment(.center)
                    
                    OpenAppButton(.zamaDataVault(tab: .profile))
                        .buttonStyle(.zama)
                        .padding(.horizontal, 20)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
            } else {
                ScrollView {
                    ForEach(vm.items) { item in
                        switch item {
                        case .post(let post): postView(post)
                        case .ad(let index, let hash): adView(position: index, profileHash: hash)
                        }
                        Divider()
                            .frame(height: 1)
                            .background(.black)
                    }
                    .padding(.horizontal, 8)
                }
            }
        }
        .background(Color.zamaGreyBackground)
        .overlay(alignment: .topTrailing) {
            if !vm.dataVaultActionNeeded {
                ZamaLink()
            }
        }
        .onAppearAgain {
            vm.refreshFromDisk()
        }
    }
    
    private var titleBar: some View {
        VStack(spacing: 4) {
            Text("FHE Ads")
                .customFont(.largeTitle)
                .frame(maxWidth: .infinity)
                .overlay(alignment: .leading) {
                    if !vm.dataVaultActionNeeded {
                        OpenAppButton(.zamaDataVault(tab: .profile)) {
                            Image(systemName: "pencil.circle.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 32, height: 32)
                                .padding(8)
                        }
                        .tint(.black)
                    }
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
    private func adView(position: Int, profileHash: String) -> some View {
        FilePreview(url: Storage.url(for: .concreteEncryptedResult, suffix: "\(profileHash)-\(position)"))
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
