// Copyright © 2025 Zama. All rights reserved.

import SwiftUI
import Charts

struct SleepChartView: View {
    let samples: [Sleep.Sample]
    
    var body: some View {
        Chart(samples) { sample in
            BarMark(
                xStart: .value("Start", sample.start),
                xEnd: .value("End", sample.end),
                y: .value("Stage", sample.level.name)
            )
            .foregroundStyle(by: .value("Stage", sample.level.name))
        }
        .chartForegroundStyleScale([
            "In Bed": .green,
            "Awake": .pink,
            "REM": .cyan,
            "Core": .blue,
            "Deep": .indigo
        ])
        .chartYScale(domain: Sleep.Level.displayOrder.map(\.name))
        .chartXScale(domain: 0...maxSampleEnd)
        .chartXAxis {
            AxisMarks(values: Array(stride(from: 0, through: maxSampleEnd, by: 120))) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel() {
                    if let intValue = value.as(Int.self) {
                        let hours = Double(intValue / 60)
                        Text("\(hours.formatted(.number.precision(.integerLength(2)))):00")
                    }
                }
            }
        }
        .chartLegend(.hidden)
        .frame(height: 150)
    }
    
    private var maxSampleEnd: Int {
        samples.map { $0.end }.max() ?? 0
    }    
}
