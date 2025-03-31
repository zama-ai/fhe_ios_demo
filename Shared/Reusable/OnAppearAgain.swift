// Copyright © 2025 Zama. All rights reserved.

import SwiftUI

struct OnAppearAgainModifier: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    let action: () -> Void
    
    func body(content: Content) -> some View {
        content
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    action() // When coming back from background (or inactive state)
                }
            }
            .onAppear()
            .task {
                action() // On app launch
            }
    }
}

extension View {
    /// Adds an action to perform before this view appears _the first time_, **or anytime this view comes back from background**
    func onAppearAgain(perform action: @escaping () -> Void) -> some View {
        self.modifier(OnAppearAgainModifier(action: action))
    }
}
