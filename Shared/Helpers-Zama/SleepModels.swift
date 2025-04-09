// Copyright © 2025 Zama. All rights reserved.

import Foundation.NSUUID

enum Sleep {
    struct Night: Equatable {
        let date: Date
        let samples: [Sample]
    }
    
    struct Sample: Identifiable, Equatable {
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
            case .inBed: "In Bed"
            case .awake: "Awake"
            case .asleepREM: "REM"
            case .asleepCore: "Core"
            case .asleepDeep: "Deep"
            case .asleepUnspecified: "Asleep"
            }
        }
        
        static let displayOrder: [Level] = [
            // .inBed,
            .awake,
            .asleepREM,
            .asleepCore,
            .asleepDeep,
            // .asleepUnspecified
        ]
    }
}

extension Sleep.Night {
    static func fakeRegular(date: Date) -> Sleep.Night {
        let values = [[0, 0, 210], [0, 240, 570], [2, 0, 30], [5, 30, 60], [3, 60, 90], [4, 90, 120], [3, 120, 150], [5, 150, 180], [2, 180, 240], [3, 240, 300], [5, 300, 330], [4, 330, 390], [2, 390, 420], [5, 420, 450], [4, 450, 510], [3, 510, 540], [5, 540, 570]]
        
        let samples: [Sleep.Sample] = values.map { row in
            Sleep.Sample(start: row[1],
                         end: row[2],
                         level: Sleep.Level(rawValue: row[0])!)
        }
        
        return Sleep.Night(date: date, samples: samples)
    }
    
    static func fakeBad(date: Date) -> Sleep.Night {
        let values = [
            [0,   0, 120],
            [3, 120, 150],
            [0, 150, 210],
            [4, 210, 240],
            [0, 240, 300]
        ]
        
        let samples: [Sleep.Sample] = values.map { row in
            Sleep.Sample(start: row[1],
                         end: row[2],
                         level: Sleep.Level(rawValue: row[0])!)
        }
        
        return Sleep.Night(date: date, samples: samples)
    }
    
    /// Helper function to create realistic sleep cycles
    static func fakeLarge(date: Date) -> Sleep.Night {
        func generateSleepCycle(startMinute: Int, cycleLength: Int) -> [(Int, Int, Sleep.Level)] {
            var segments: [(Int, Int, Sleep.Level)] = []
            var currentMinute = startMinute
            
            // Light sleep (Core)
            let lightSleepDuration = Int.random(in: 20...30)
            segments.append((currentMinute, currentMinute + lightSleepDuration, .asleepCore))
            currentMinute += lightSleepDuration
            
            // Deep sleep
            let deepSleepDuration = Int.random(in: 15...25)
            segments.append((currentMinute, currentMinute + deepSleepDuration, .asleepDeep))
            currentMinute += deepSleepDuration
            
            // More light sleep
            let lightSleep2Duration = Int.random(in: 20...30)
            segments.append((currentMinute, currentMinute + lightSleep2Duration, .asleepCore))
            currentMinute += lightSleep2Duration
            
            // REM sleep
            let remSleepDuration = Int.random(in: 15...25)
            segments.append((currentMinute, currentMinute + remSleepDuration, .asleepREM))
            currentMinute += remSleepDuration
            
            // Possible brief awakening
            if Bool.random() {
                let awakeningDuration = Int.random(in: 3...8)
                segments.append((currentMinute, currentMinute + awakeningDuration, .awake))
                currentMinute += awakeningDuration
            }
            
            return segments
        }
        
        var allSegments: [(Int, Int, Sleep.Level)] = []
        
        // Initial falling asleep period
        allSegments.append((0, 15, .awake))
        allSegments.append((15, 30, .asleepCore))
        
        // Generate 6-7 sleep cycles
        let numberOfCycles = Int.random(in: 6...7)
        var currentMinute = 30
        
        for _ in 0..<numberOfCycles {
            let cycleLength = Int.random(in: 90...120)
            let cycleSegments = generateSleepCycle(startMinute: currentMinute, cycleLength: cycleLength)
            allSegments.append(contentsOf: cycleSegments)
            currentMinute += cycleLength
        }
        
        // Add some final awakening periods
        allSegments.append((currentMinute, currentMinute + 10, .awake))
        
        // Convert to Sleep.Sample array
        let samples = allSegments.map { segment in
            Sleep.Sample(
                start: segment.0,
                end: segment.1,
                level: segment.2
            )
        }
        
        return Sleep.Night(date: date, samples: samples)
    }
}
