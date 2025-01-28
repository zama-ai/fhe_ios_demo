// Copyright © 2025 Zama. All rights reserved.

import SwiftUI

#Preview {
    AdsView()
}

struct AdsView: View {
    @StateObject private var vm = ViewModel.preview
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        VStack {
            titleBar
                .padding(.top, 8)
            
            ScrollView {
                disclaimer
                
                ForEach(Array(vm.posts.enumerated()), id: \.offset) { index, post in
                    postView(post)
                    if index % 2 == 1 {
                        adView(vm.ads[index % vm.ads.count])
                    }
                }
                .padding(.horizontal, 8)
            }
        }
        .background(.orange)
    }
    
    private var titleBar: some View {
        VStack(spacing: 0) {
            Text("FHE Ad Targeting")
                .customFont(.largeTitle)
                .frame(maxWidth: .infinity)
            
            OpenAppButton(.fheDataVault) {
                Label("Edit Profile", systemImage: "person.crop.circle.fill")
            }
            .padding(6)
            .buttonStyle(.bordered)
            .tint(.black)
        }
    }
    
    private var disclaimer: some View {
        Text("""
            This app **never** accesses your profile info (by design, it technically cannot), yet it can display targeted ads.
            Learn how **[Zama](https://zama.ai)** makes it possible using Fully Homomorphic Encryption (FHE).
            """)
        .customFont(.subheadline)
        .multilineTextAlignment(.center)
        .tint(.black)
        .padding(.bottom)
    }
    
    private func adView(_ ad: Ad) -> some View {
        GroupBox {
            HStack(alignment: .top) {
                AsyncImage(url: ad.url)
                    .overlay { ad.color.opacity(0.2) }
                    .frame(width: 80, height: 80)
                    .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(ad.title).font(.headline)
                    
                    HStack(alignment: .top) {
                        Text(ad.subtitle)
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Button(ad.action) {
                            print("Ad tapped")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(ad.color)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private func postView(_ post: Post) -> some View {
        GroupBox {
            HStack(alignment: .top) {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .frame(width: 32, height: 32)
                    .foregroundStyle(.tertiary)
                
                VStack(alignment: .leading) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(post.username)
                            .customFont(.headline)
                        
                        Text(post.timestamp)
                            .customFont(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding(.bottom, 2)
                    
                    Text(post.content)
                        .customFont(.body)
                        .foregroundColor(.primary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
