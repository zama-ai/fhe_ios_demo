// Copyright © 2025 Zama. All rights reserved.

import SwiftUI

#Preview {
    Group {
        AsyncButton("Try me!") {}

        AsyncButton(action: {}) {
            Text("Text based button")
        }

        AsyncButton(action: {}) {
            Image(systemName: "heart.text.clipboard")
        }

        AsyncButton(action: {}) {
            Label("Import Health Information", systemImage: "heart.text.clipboard")
                .symbolRenderingMode(.multicolor)
        }
        
        AsyncButton("Try me! (error)") {
            throw NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Something went wrong!"])
        }
    }
    .buttonStyle(.bordered)
}

struct AsyncButton<Label: View>: View {
    private let action: () async throws -> Void
    private let label: () -> Label
    
    @State private var task: Task<Void, Never>?
    @State private var errorMessage: String?
        
    init(action: @escaping () async throws -> Void, @ViewBuilder label: @escaping () -> Label) {
        self.action = action
        self.label = label
    }
    
    init(_ title: String, action: @escaping () async throws -> Void) where Label == Text {
        self.action = action
        self.label = { Text(title) }
    }

    var body: some View {
        Button {
            guard task == nil else {
                return
            }
            task = Task {
                do {
                    try await Task.sleep(for: .seconds(0.4))
                    try await action()
                } catch {
                    errorMessage = error.localizedDescription
                }
                task = nil
            }
        } label: {
            label()
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
