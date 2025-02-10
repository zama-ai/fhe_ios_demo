// Copyright © 2025 Zama. All rights reserved.

import SwiftUI

#Preview {
    let me = Profile(gender: .male,
                     age: .middle_adult,
                     language: .french,
                     country: .france,
                     interestedInKids: false,
                     interests: [.art, .photography, .sports, .writers])
    Text("\(me.oneHotBinary)")
}

protocol PrettyNamable {}
extension PrettyNamable {
    var prettyTypeName: String {
        String(describing: self)
            .replacingOccurrences(of: "_", with: " ")
            .localizedCapitalized
    }
}

protocol OneHotable: CaseIterable where Self: Equatable {
    var oneHot: [Bool] { get }
}

extension OneHotable {
    var oneHot: [Bool] {
        Self.allCases.map { $0 == self }
    }
}

struct EditProfile {
    var gender: Gender?
    var age: AgeGroup?
    var language: Language
    var country: Country
    
    var interestedInKids: Bool
    var interests: Interest?
    
    init() {
        self.gender = nil
        self.age = nil
        
        let deviceLanguage = Locale.preferredLanguages.first?.split(separator: "-").first.flatMap(String.init) // e.g., "en-US"
        let deviceCountry = Locale.current.region?.identifier // e.g., "US"
        
        self.language = deviceLanguage.flatMap(Language.init(rawValue:)) ?? .english
        self.country = deviceCountry.flatMap(Country.init(rawValue:)) ?? .united_states
        
        self.interestedInKids = false
        self.interests = nil
    }
}

struct Profile {
    let gender: Gender
    let age: AgeGroup
    let language: Language
    let country: Country
    
    let interestedInKids: Bool
    let interests: Set<Interest>
    
    var oneHot: [Bool] {
        [
            gender.oneHot,
            age.oneHot,
            language.oneHot,
            [interestedInKids],
            country.oneHot,
            Interest.allCases.map { interests.contains($0) }
        ].flatMap(\.self)
    }
    
    var oneHotBinary: [UInt64] {
        oneHot.map { $0 ? 1 : 0 }
    }
}

extension Profile {
    init?(editProfile edit: EditProfile) {
        guard let g = edit.gender, let a = edit.age, let i = edit.interests else {
            return nil
        }
        
        self = Profile(gender: g,
                       age: a,
                       language: edit.language,
                       country: edit.country,
                       interestedInKids: edit.interestedInKids,
                       interests: [i])
    }
}

enum MaritalStatus: PrettyNamable, CaseIterable {
    case single, engaged
}

enum Gender: PrettyNamable, OneHotable {
    case female, male
}

enum AgeGroup: Int, OneHotable {
    case child = 12
    case teen = 19
    case young_adult = 45
    case middle_adult = 60
    case senior = 999
    
    var range: ClosedRange<Int> {
        switch self {
        case .child:        0...self.rawValue
        case .teen:         (AgeGroup.child.rawValue + 1)...self.rawValue
        case .young_adult:   (AgeGroup.teen.rawValue + 1)...self.rawValue
        case .middle_adult:  (AgeGroup.young_adult.rawValue + 1)...self.rawValue
        case .senior:       (AgeGroup.middle_adult.rawValue + 1)...Int.max
        }
    }
    
    var displayName: String {
        if range.upperBound == Int.max {
            "\(range.lowerBound)+"
        } else {
            "\(range.lowerBound)-\(range.upperBound)"
        }
    }
}

enum Language: String, PrettyNamable, OneHotable {
    case arabic = "ar"
    case english = "en"
    case french = "fr"
    case german = "de"
    case hindi = "hi"
    case italian = "it"
    case japanese = "ja"
    case mandarin = "zh"
    case spanish = "es"
    case tamazight = "ber"
    case tamil = "ta"

    var languageNames: (native: String, translated: String) {
        let native = Locale(identifier: rawValue).localizedString(forLanguageCode: rawValue)?.localizedCapitalized
        let clear = Locale.current.localizedString(forLanguageCode: rawValue)?.localizedCapitalized
        return (native: native ?? prettyTypeName, translated: clear ?? prettyTypeName)
    }
}

enum Country: String, PrettyNamable, OneHotable {
    case united_arab_emirates = "AE",
         united_states = "US",
         france = "FR",
         china = "CN",
         germany = "DE",
         united_kingdom = "GB",
         japan = "JP",
         india = "IN",
         canada = "CA",
         italy = "IT",
         algeria = "DZ",
         australia = "AU",
         spain = "ES"
    
    var localizedCountryName: String {
        Locale.current.localizedString(forRegionCode: rawValue) ?? prettyTypeName
    }
    
    var flag: String {
        let countryCode = rawValue.uppercased()
        guard countryCode.count == 2 else { return "" }
        
        let base: UInt32 = 0x1F1E6 // Regional Indicator Symbol 'A' starts at this Unicode code point
        
        // Convert each character to its corresponding regional indicator symbol
        let flag = countryCode.compactMap { char -> String? in
            guard let scalar = Unicode.Scalar(String(char)) else { return nil }
            let codePoint = base + scalar.value - Unicode.Scalar("A").value
            return String(UnicodeScalar(codePoint)!)
        }
        
        return flag.joined()
    }
}

enum Interest: PrettyNamable, OneHotable {
    case animals,
         art,
         automobiles,
         bicycle,
         books,
         comedy,
         comics,
         culture,
         education,
         family,
         fashion,
         food,
         health,
         journalism,
         movies,
         music,
         nature,
         news,
         pets,
         photography,
         politics,
         science,
         smartphones,
         software_dev,
         sports,
         tv,
         tech,
         travel,
         video_games,
         writers
}
