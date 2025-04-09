// Copyright © 2025 Zama. All rights reserved.

import Foundation

enum TimelineItem: Identifiable {
    case post(Post)
    case ad(position: Int, profileHash: String)
    
    var id: String {
        switch self {
        case .post(let post): "post-\(post.id)"
        case .ad(let position, let hash): "ad-\(position)-\(hash)"
        }
    }
}

struct Post: Identifiable {
    let id = UUID()
    let username: String
    let handle: String
    let content: String
    let timestamp: String
    
    static let samples: [Post] = [
        Post(username: "UserA", handle:"@dataprivacy", content: "Privacy should be the default, not an option users have to search for.", timestamp: "3m"),
        Post(username: "UserB", handle:"@cleanCoder", content: "Writing clean code is easy. Writing readable code that lasts? That’s the challenge.", timestamp: "10m"),
        Post(username: "UserC", handle:"@debugmaster", content: "Every bug hides a lesson. Every fix is a step closer to mastery.", timestamp: "1h"),
        Post(username: "UserD", handle:"@opensourcefan", content: "Open-source encryption libraries are essential. Trust, but verify.", timestamp: "2h"),
        Post(username: "UserE", handle:"@uxmatters", content: "Good UX means protecting users’ data, not just their experience.", timestamp: "3h"),
        Post(username: "UserF", handle:"@devthinking", content: "Learning a new programming language feels like unlocking a new way to think.", timestamp: "5h"),
        Post(username: "UserG", handle:"@breachwatch", content: "Data breaches aren’t just technical failures—they're ethical ones too.", timestamp: "8h"),
        Post(username: "UserH", handle:"@simplecoder", content: "Complex passwords protect data. Simple code protects developers.", timestamp: "12h"),
        Post(username: "UserI", handle:"@privacyfirst", content: "In a world full of trackers, privacy is a power move.", timestamp: "1d"),
        Post(username: "UserJ", handle:"@privacyguru", content: "Encryption isn't just for security—it’s about preserving freedom in the digital world.", timestamp: "2d")
    ]
}

enum ActivityReport {
    case progress(String)
    case error(String)
}

enum CustomError: LocalizedError {
    case missingServerKey
    case missingProfile
    
    var errorDescription: String {
        switch self {
        case .missingServerKey: "Missing ServerKey - Open DataVault to regenerate one."
        case .missingProfile: "Missing Profile - Open DataVault to regenerate one."
        }
    }
}
