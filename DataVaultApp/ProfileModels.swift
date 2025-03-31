// Copyright © 2025 Zama. All rights reserved.

import SwiftUI

#Preview {
    let me = Profile(age: .middle_adult,
                     gender: .male,
                     country: .france,
                     language: .french,
                     interests: [.art, .photography, .sports, .writers])
    Text("\(me.oneHotBinary)")
}

protocol OneHotable: CaseIterable where Self: Equatable {
    var oneHot: [Bool] { get }
}

extension OneHotable {
    var oneHot: [Bool] {
        Self.allCases.map { $0 == self }
    }
}

struct Profile: Equatable {
    let age: AgeGroup
    let gender: Gender
    let country: Country
    let language: Language
    let interests: Set<Interest>
    
    var oneHot: [Bool] {
        let nonKidsInterests = interests.filter {$0 != .kids}
        let interestedInKids = interests.contains(.kids)
        
        return [
            gender.oneHot,
            age.oneHot,
            language.oneHot,
            [interestedInKids],
            country.oneHot,
            Interest.allCasesExcludingKids.map { nonKidsInterests.contains($0) }
        ].flatMap(\.self)
    }
    
    var oneHotBinary: [UInt64] {
        oneHot.map { $0 ? 1 : 0 }
    }
}

extension Profile {
    init?(ageGroup: AgeGroup?, gender: Gender?, country: Country?, language: Language?, interests: Set<Interest>) {
        guard let ageGroup, let gender, let country, let language, !interests.isEmpty else {
            return nil
        }
        
        self = Profile(age: ageGroup,
                       gender: gender,
                       country: country,
                       language: language,
                       interests: interests)
    }
    
    init?(from oneHot: [UInt64]) {
        var oneHot = oneHot
        guard !oneHot.isEmpty else { return nil }
        let (genderHot, ageHot, languageHot, kidsHot, countryHot, interestsHot) = (
            oneHot.popFirst(Gender.allCases.count),
            oneHot.popFirst(AgeGroup.allCases.count),
            oneHot.popFirst(Language.allCases.count),
            oneHot.removeFirst(),
            oneHot.popFirst(Country.allCases.count),
            oneHot.popFirst(Interest.allCases.count - 1)
        )
        
        let ageGroup = zip(ageHot, AgeGroup.allCases).first(where: { $0.0 == 1 })?.1
        let gender = zip(genderHot, Gender.allCases).first(where: { $0.0 == 1 })?.1
        let country = zip(countryHot, Country.allCases).first(where: { $0.0 == 1 })?.1
        let language = zip(languageHot, Language.allCases).first(where: { $0.0 == 1 })?.1
        let interestsTMP = zip(interestsHot, Interest.allCasesExcludingKids).filter({ $0.0 == 1 }).map { $0.1 }
        var interests = Set(interestsTMP)
        if kidsHot == 1 {
            interests.insert(.kids)
        }
        
        if let p = Profile(ageGroup: ageGroup, gender: gender, country: country, language: language, interests: interests) {
            self = p
        } else {
            return nil
        }
    }
}

enum Gender: PrettyTypeNamable, OneHotable {
    case female, male
}

enum AgeGroup: Int, OneHotable {
    case child = 12
    case teen = 19
    case young_adult = 45
    case middle_adult = 60
    case senior = 999
    
    init(age: Int) {
        if age <= AgeGroup.child.rawValue {
            self = .child
        } else if age <= AgeGroup.teen.rawValue {
            self = .teen
        } else if age <= AgeGroup.young_adult.rawValue {
            self = .young_adult
        } else if age <= AgeGroup.middle_adult.rawValue {
            self = .middle_adult
        } else {
            self = .senior
        }
    }
    
    var exampleAge: Int {
        switch self {
        case .child: 2
        case .teen: AgeGroup.child.rawValue + 2
        case .young_adult: AgeGroup.teen.rawValue + 2
        case .middle_adult: AgeGroup.young_adult.rawValue + 2
        case .senior: AgeGroup.middle_adult.rawValue + 2
        }
    }
}

enum Language: String, PrettyTypeNamable, OneHotable {
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
    
    var names: (native: String, translated: String) {
        let native = Locale(identifier: rawValue).localizedString(forLanguageCode: rawValue)?.localizedCapitalized
        let clear = Locale.current.localizedString(forLanguageCode: rawValue)?.localizedCapitalized
        return (native: native ?? prettyTypeName, translated: clear ?? prettyTypeName)
    }
}

enum Country: String, PrettyTypeNamable, OneHotable {
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

enum Interest: String, PrettyTypeNamable, CaseIterable {
    
    static var allCasesPlusKids: [Interest] {
        Self.allCases
    }
    
    static var allCasesExcludingKids: [Interest] {
        Self.allCases.filter { $0 != .kids}
    }
    
    case animals
    case art
    case automobiles
    case bicycle
    case books
    case comedy
    case comics
    case culture
    case education
    case family
    case fashion
    case food
    case health
    case journalism
    case kids // Added as an Interest, it is a feature of its own actually for the server (like Gender, Language…)
    case movies
    case music
    case nature
    case news
    case pets
    case photography
    case politics
    case science
    case smartphones
    case software_dev
    case sports
    case tv
    case tech
    case travel
    case video_games
    case writers
}

fileprivate extension Array {
    mutating func popFirst(_ n: Int) -> [Element] {
        return (0..<Swift.min(n, count)).map { _ in removeFirst() }
    }
}
