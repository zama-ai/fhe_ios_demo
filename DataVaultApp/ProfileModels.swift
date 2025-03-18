// Copyright © 2025 Zama. All rights reserved.

import SwiftUI

#Preview {
    let me = Profile(age: .middle_adult,
                     gender: .male,
                     country: .france,
                     language: .french,
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

struct Profile {
    let age: AgeGroup
    let gender: Gender
    let country: Country
    let language: Language

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
    init?(age: Int?, gender: Gender?, country: Country?, language: Language?, interests: Set<Interest>) {
        guard let age, let gender, let country, let language else {// FIXME: }, !interests.isEmpty else {
            return nil
        }
        
        self = Profile(age: AgeGroup(age: age),
                       gender: gender,
                       country: country,
                       language: language,
                       interestedInKids: false, // TODO: FIXME
                       interests: interests)
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

    var names: (native: String, translated: String) {
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

enum Interest: String, PrettyNamable, OneHotable {
    case animals = "🐾"
    case art = "🎨"
    case automobiles = "🚗"
    case bicycle = "🚴"
    case books = "📚"
    case comedy = "😂"
    case comics = "🦸"
    case culture = "🎭"
    case education = "🎓"
    case family = "👨‍👩‍👧‍👦"
    case fashion = "👗"
    case food = "🍽"
    case health = "🏥"
    case journalism = "🖊️"
    case movies = "🎬"
    case music = "🎵"
    case nature = "🌿"
    case news = "🗞"
    case pets = "🐶"
    case photography = "📸"
    case politics = "🏛"
    case science = "🔬"
    case smartphones = "📱"
    case software_dev = "💻"
    case sports = "⚽️"
    case tv = "📺"
    case tech = "🖥"
    case travel = "✈️"
    case video_games = "🎮"
    case writers = "✍️"
}
