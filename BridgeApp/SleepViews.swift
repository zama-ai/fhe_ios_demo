// Copyright © 2024 Zama. All rights reserved.

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
            AxisMarks(values: Array(stride(from: 0, through: maxSampleEnd, by: 60))) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel()
            }
        }
        .chartLegend(.hidden)
        .frame(height: 150)
        .padding()
    }
    
    var maxSampleEnd: Int {
        samples.map { $0.end }.max() ?? 0
    }
}

#Preview {
    SleepChartView(samples: Sleep.Night.fake.samples)
}
