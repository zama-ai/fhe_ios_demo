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
            "Awake": .pink,
            "REM": .cyan,
            "Core": .blue,
            "Deep": .indigo,
            "in Bed": .green
        ])
        .chartLegend(.hidden)
        .frame(height: 150)
        .padding()
    }
}

#Preview {
    SleepChartView(samples: Sleep.Night.fake.samples)
}
