// Copyright © 2024 Zama. All rights reserved.

import Foundation.NSUUID

enum Sleep {
    struct Night {
        let date: Date
        let samples: [Sample]
        
        static let fake: Night = {
            let slotInMinutes = 30
            let values = [[0, 0, 210], [0, 240, 570], [2, 0, 30], [5, 30, 60], [3, 60, 90], [4, 90, 120], [3, 120, 150], [5, 150, 180], [2, 180, 240], [3, 240, 300], [5, 300, 330], [4, 330, 390], [2, 390, 420], [5, 420, 450], [4, 450, 510], [3, 510, 540], [5, 540, 570]]
            
            let samples: [Sleep.Sample] = values.map { row in
                Sleep.Sample(start: row[1],
                             end: row[2],
                             level: Sleep.Level(rawValue: row[0])!)
            }
            
            // Go to bed at 11pm
            let start = Calendar.current.startOfDay(for: Date()).addingTimeInterval(-1*3600)
            
            return Night(date: start, samples: samples)
        }()

    }
    
    struct Sample: Identifiable {
        let id = UUID()
        let start: Int  // Minutes since night start
        let end: Int    // Minutes since night start
        let level: Level
    }
    
    // Mirrors HKCategoryValueSleepAnalysis
    enum Level: Int, CaseIterable {
        case inBed = 0
        case asleepUnspecified = 1
        case awake = 2
        case asleepCore = 3 // Stages 1 and 2 of AASM model
        case asleepDeep = 4 // Stage 3 of AASM model
        case asleepREM = 5  // REM stage of AASM model
        
        var name: String {
            switch self {
            case .awake: "Awake"
            case .asleepREM: "REM"
            case .asleepCore: "Core"
            case .asleepDeep: "Deep"
            case .inBed: "in Bed"
            case .asleepUnspecified: "asleep"
            }
        }
    }
}
