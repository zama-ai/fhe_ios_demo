// Copyright © 2024 Zama. All rights reserved.

import SwiftUI

struct AsyncButton: View {
    private let title: String
    private let action: () async -> Void
    @State private var task: Task<Void, Never>?

    init(_ title: String, action: @escaping () async -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button {
            guard task == nil else {
                return
            }
            task = Task {
                await action()
                task = nil
            }
        } label: {
            Text(title)
                .opacity(task == nil ? 1 : 0)
                .overlay {
                    ProgressView()
                        .opacity(task == nil ? 0 : 1)
                }
        }
    }
}

#Preview {
    AsyncButton("Try me!") {
        try? await Task.sleep(for: .seconds(2))
    }
    .buttonStyle(.borderedProminent)
}
