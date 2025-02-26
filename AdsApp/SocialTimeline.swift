// Copyright © 2025 Zama. All rights reserved.

import SwiftUI

#Preview {
    SocialTimeline()
}

struct SocialTimeline: View {
    @StateObject private var vm = ViewModel.preview
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        VStack {
            titleBar
                .padding(.top, 8)
            
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
        .background(.orange)
    }
    
    private var titleBar: some View {
        HStack(spacing: 0) {
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
