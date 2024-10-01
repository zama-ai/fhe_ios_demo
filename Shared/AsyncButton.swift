// Copyright © 2024 Zama. All rights reserved.

import SwiftUI

struct AsyncButton: View {
    private let title: String
    private let action: () async throws -> Void
    @State private var task: Task<Void, Never>?
    @State private var errorMessage: String?

    init(_ title: String, action: @escaping () async throws -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button {
            guard task == nil else {
                return
            }
            task = Task {
                do {
                    try await action()
                } catch {
                    errorMessage = error.localizedDescription
                }
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
        .disabled(task != nil)
        .alert(isPresented: .constant(errorMessage != nil)) {
                    Alert(
                        title: Text("Error"),
                        message: Text(errorMessage ?? "Unknown error"),
                        dismissButton: .default(Text("OK")) {
                            errorMessage = nil
                        }
                    )
                }
    }
}

#Preview {
    Group {
        AsyncButton("Try me!") {
            try? await Task.sleep(for: .seconds(2))
        }
        AsyncButton("Try me!") {
            try? await Task.sleep(for: .seconds(1))
            throw NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Something went wrong!"])
        }
    }
    .buttonStyle(.bordered)
}
