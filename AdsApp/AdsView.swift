// Copyright © 2024 Zama. All rights reserved.

import SwiftUI

#Preview {
    AdsView()
}

struct AdsView: View {
    @StateObject private var vm = ViewModel()
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack {
            titleBar
                .padding(.top, 8)
            
            ScrollView {
                disclaimer
                
                ForEach(Array(vm.samplePosts.enumerated()), id: \.offset) { index, post in
                    postView(post)
                    if index % 2 == 1 {
                        adView(vm.sampleAds[index % vm.sampleAds.count])
                    }
                }
                .padding(.horizontal, 8)
            }
        }
        .background(.orange)
    }
    
    private var titleBar: some View {
        Text("FHE Ad Targeting")
            .customFont(.largeTitle)
            .frame(maxWidth: .infinity)
            .overlay(alignment: .trailing) {
                Button {
                    print("profile")
                    openURL(URL(string: "fhedatavault://")!)
                } label: {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .frame(width: 32, height: 32)
                        .padding()
                }
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
                ad.color.frame(width: 80, height: 80)
                
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
