// Copyright © 2025 Zama. All rights reserved.

import SwiftUI

struct SleepQualityView: View {
    let quality: SleepQuality
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                gauge(quality)
                Text(quality.details)
            }
            Text(quality.tip)
        }
        .fontWeight(.regular)
        .customFont(.footnote)
    }
    
    private func gauge(_ quality: SleepQuality) -> some View {
        let min = SleepQuality.allCases.startIndex + 1
        let max = SleepQuality.allCases.endIndex
        return Gauge(value: Double(quality.rawValue), in: Double(min)...Double(max), label: {
            Text("")
        }, currentValueLabel: {
            Text("\(quality.rawValue)")
        }, minimumValueLabel: {
            Text("\(min)")
        }, maximumValueLabel: {
            Text("\(max)")
        })
        .gaugeStyle(.accessoryCircular)
        .tint(Gradient(colors: [.green, .yellow, .orange, .red, .pink]))
    }
}

enum SleepQuality: Int, CaseIterable, PrettyTypeNamable {
    case excellent = 1
    case good = 2
    case moderate = 3
    case poor = 4
    case veryPoor = 5
    
    var details: LocalizedStringKey {
        switch self {
        case .excellent:
            "**Excellent Rest**: You achieved a long sleep, with sufficient REM and Deep Sleep stages for recovery and memory consolidation."
            
        case .good:
            "**Good Sleep**: Your sleep was solid, with adequate REM and Deep Sleep, though there’s room for slight improvement in overall recovery."
            
        case .moderate:
            "**Moderate Sleep**: Your sleep was somewhat fragmented, with either reduced Deep or REM sleep, impacting recovery and cognitive function."
            
        case .poor:
            "**Poor Sleep**: Your sleep lacked enough Deep or REM stages, affecting physical restoration and mental clarity."
            
        case .veryPoor:
            "**Very Poor Sleep**: Your sleep was highly disrupted, with insufficient restorative phases, leading to fatigue and impaired cognitive function."
        }
    }
    
    var tip: LocalizedStringKey {
        switch self {
        case .excellent:
            "**Tip**: Keep your bedroom cool and dark to enhance your REM sleep."
            
        case .good:
            "**Tip**: Try maintaining a consistent bedtime to enhance sleep stability and optimize deep sleep."
            
        case .moderate:
            "**Tip**: Reduce screen time before bed to improve melatonin production and deepen sleep."
            
        case .poor:
            "**Tip¨**: Avoid caffeine in the afternoon to prevent disruptions in deep sleep cycles."
            
        case .veryPoor:
            "**Tip**: Prioritize a wind-down routine before bed, such as reading or meditation, to improve sleep quality."
        }
    }
}
