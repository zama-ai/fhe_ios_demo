// Copyright © 2025 Zama. All rights reserved.

import SwiftUI

#Preview {
    ZamaInfoButton()
    Spacer()
}

struct ZamaInfoButton: View {
    @State private var isPresented: Bool = false
    
    private var infoText: String = {
        """
        The information on this page is visible only by you and the 'Data Vault' app which stores your sensitive data. 
        
        The '\(AppInfo.appName)' app does not have access to this data.
        """
    }()
    
    var body: some View {
        Button(action: {
            isPresented = true
        }, label: {
            Image(systemName: "info.circle")
                .padding()
        })
        .offset(x: -0, y: 40)
        .tint(.black)
        .fullScreenCover(isPresented: $isPresented) {
            content
        }
    }
    
    private var content: some View {
        NavigationStack {
            VStack {
                Text(infoText)
                    .multilineTextAlignment(.center)
                    .padding(50)
                    .presentationBackground {
                        Color.black.opacity(0.7)
                    }
                    .presentationBackground(.ultraThinMaterial)
                
                Button("OK") {
                    isPresented = false
                }.buttonStyle(.bordered)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark")
                            .padding()
                    }
                }
            }
        }
        .environment(\.colorScheme, .dark)
        .customFont(.body)
        .tint(.zamaOrange)
    }
}
