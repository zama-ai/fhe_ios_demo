// Copyright © 2025 Zama. All rights reserved.

import Foundation

enum ActivityStatus {
    case progress(String)
    case error(String)
}

enum CustomError: LocalizedError {
    case missingServerKey
    
    var errorDescription: String {
        switch self {
        case .missingServerKey: "Missing ServerKey - Open DataVault to regenerate one."
        }
    }
}

import SwiftUI

struct AsyncStatus: View {
    private let status: ActivityStatus
    
    init(_ status: ActivityStatus) {
        self.status = status
    }
    
    var body: some View {
        VStack {
            switch status {
            case .progress(let string):
                Text(string)
                Spacer().overlay {
                    ProgressView()
                        .tint(nil)
                }
                Text("This process might take some time.")
                
            case .error(let string):
                Text("⚠️ " + string)
            }
        }
        .foregroundStyle(.secondary)
        .customFont(.callout)
        .fontWeight(.regular)
    }
}
