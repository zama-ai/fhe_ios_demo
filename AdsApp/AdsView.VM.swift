// Copyright © 2024 Zama. All rights reserved.

import Foundation
import SwiftUI

struct Post: Identifiable {
    let id = UUID()
    let username: String
    let content: String
    let timestamp: String
}

struct Ad: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let action: String
    var color: Color
    let url: URL = {
        let id = (0...30).randomElement()!
        return URL(string: "https://picsum.photos/id/\(id)/80/80")!
    }()
}

extension AdsView.ViewModel {
    static let preview = AdsView.ViewModel(
        posts: [
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
        ],
        ads: [
            Ad(title: "Secure Cloud Storage", subtitle: "Store your files safely with end-to-end encryption.", action: "Start Free Trial", color: .pink),
            Ad(title: "Protect Your Identity", subtitle: "Use VPN services to stay anonymous online.", action: "Sign Up", color: .teal),
            Ad(title: "Master SwiftUI", subtitle: "Join our advanced SwiftUI course today.", action: "Enroll Now", color: .green),
            Ad(title: "Boost Your Privacy", subtitle: "Get the latest encryption tools to secure your data.", action: "Learn More", color: .brown),
            Ad(title: "Code Smarter, Not Harder", subtitle: "Discover tips and tricks to improve your coding efficiency.", action: "Get Tips", color: .red)
        ]
    )
}

extension AdsView {
    final class ViewModel: ObservableObject {
        @Published var posts: [Post]
        @Published var ads: [Ad]
        
        init(posts: [Post], ads: [Ad]) {
            self.posts = posts
            self.ads = ads
        }
    }
}
