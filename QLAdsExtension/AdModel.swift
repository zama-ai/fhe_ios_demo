
/* An Ad is defined in `ads.json` as a tuple of:
 (ad_title, ad_country, target_countries, ad_language, target_age_group, target_gender, area of interests, weighted_interest, description, image_path)
 
 We only parse the few fields we are interested in.
 
 Ex:
 "0":["Discover Adventure in the Grand Canyon", 1, [1], ["English"], [1,2,3], [0,1], ["Travel","Sports"], [5,4], "Embark on a thrilling adventure in the iconic Grand Canyon with outdoor sports tailored for all ages. Book now for an unforgettable experience!", "img_travel_sports_usa_0.jpeg"],
 */

import Foundation

struct AdModel: Decodable, Identifiable {
    let id: Int // 0 - 4953
    let title: String
    let details: String
    let imageName: String
    
    static let fake = AdModel(id: 4953,
                              title: "Learn to Play Darbuka from Professionals",
                              details: "Atelier pour apprendre à jouer du darbuka. Prix : 1500 DZD par session. Sessions les samedis et mardis à 17h.",
                              imageName: "0fbfa1e096c0c87bfcc11c16c86a6f09f360f905.jpeg")
    
    static func allAds(from data: Data) throws -> [AdModel] {
        let decodedDictionary = try JSONDecoder().decode([Int: [DecodableValue]].self, from: data)
        let ads = try decodedDictionary.map { key, values in
            return AdModel(id: key,
                           title: try values[0].stringValue(),
                           details: try values[8].stringValue(),
                           imageName: try values[9].stringValue())
        }.sorted(by: { $0.id < $1.id })
        return ads
    }
}

// Helper struct to handle mixed types
enum DecodableValue: Decodable {
    case int(Int)
    case string(String)
    case arrayOfInt([Int])
    case arrayOfString([String])
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            self = .int(intValue)
        } else if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else if let arrayInt = try? container.decode([Int].self) {
            self = .arrayOfInt(arrayInt)
        } else if let arrayString = try? container.decode([String].self) {
            self = .arrayOfString(arrayString)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported type")
        }
    }
    
    func stringValue() throws -> String {
        if case let .string(value) = self { return value }
        throw DecodingError.typeMismatch(String.self, DecodingError.Context(codingPath: [], debugDescription: "Expected String"))
    }
}
