// Copyright © 2024 Zama. All rights reserved.

import Foundation

struct Post: Identifiable {
    let id = UUID()
    let username: String
    let content: String
    let timestamp: String
}

extension AdsView {
    final class ViewModel: ObservableObject {
        @Published var posts: [Post] = [
            Post(username: "@dataprivacy", content: "Privacy should be the default, not an option users have to search for.", timestamp: "3m ago"),
            Post(username: "@cleanCoder", content: "Writing clean code is easy. Writing readable code that lasts? That’s the challenge.", timestamp: "10m ago"),
            Post(username: "@debugmaster", content: "Every bug hides a lesson. Every fix is a step closer to mastery.", timestamp: "1h ago"),
            Post(username: "@opensourcefan", content: "Open-source encryption libraries are essential. Trust, but verify.", timestamp: "2h ago"),
            Post(username: "@uxmatters", content: "Good UX means protecting users’ data, not just their experience.", timestamp: "3h ago"),
            Post(username: "@devthinking", content: "Learning a new programming language feels like unlocking a new way to think.", timestamp: "5h ago"),
            Post(username: "@breachwatch", content: "Data breaches aren’t just technical failures—they're ethical ones too.", timestamp: "8h ago"),
            Post(username: "@simplecoder", content: "Complex passwords protect data. Simple code protects developers.", timestamp: "12h ago"),
            Post(username: "@privacyfirst", content: "In a world full of trackers, privacy is a power move.", timestamp: "1d ago"),
            Post(username: "@privacyguru", content: "Encryption isn't just for security—it’s about preserving freedom in the digital world.", timestamp: "2d ago")
        ]
    }
}
