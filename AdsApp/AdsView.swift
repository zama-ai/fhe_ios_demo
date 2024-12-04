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
                
                ForEach(vm.posts) { post in
                    postView(post)
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
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}
