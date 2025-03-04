// Copyright © 2025 Zama. All rights reserved.

import SwiftUI
import Charts

#Preview {
    let vm = PreviewContent.ViewModel(data: .gauge(value: 3, range: 1...5, title: "Sleep Quality", labels: ["Excellent", "Good", "Average", "Poor", "Awful"]))
    PreviewContent(viewModel: vm)
        .border(.red)
        .border(.green)
}

struct PreviewContent: View {
    @ObservedObject var viewModel = ViewModel()
    
    final class ViewModel: ObservableObject {
        @Published var data: Kind?
        
        init(data: PreviewContent.Kind? = nil) {
            self.data = data
        }
    }
    
    enum Kind {
        case text(value: Double)
        case gauge(value: Int, range: ClosedRange<Int>, title: String, labels: [String])
        case simpleChart([Double])
        case sleepChart([Sleep.Sample])
    }
    
    var body: some View {
        switch viewModel.data {
        case let .gauge(value, range, title, labels):
            gauge(value: value, range: range, title: title, labels: labels)
            
        case .text(let value):
            text(value: value)
            
        case .simpleChart(let values):
            simpleChart(values)
            
        case .sleepChart(let samples):
            SleepChartView(samples: samples)
            
        case .none:
            Color.red
        }
    }
    
    private func text(value: Double)  -> some View {
        Text("\(value.formatted(.number.precision(.fractionLength(1))))")
    }
    
    private func gauge(value: Int, range: ClosedRange<Int>, title: String, labels: [String]) -> some View {
        VStack(spacing: 0) {
            Gauge(value: Double(value), in: Double(range.lowerBound)...Double(range.upperBound)) {
                Text(title)
            } currentValueLabel: {
                VStack(spacing: 0) {
                    Text("\(value)")
                        .customFont(.title2)
                }
            } minimumValueLabel: {
                Text("\(range.lowerBound)")
            } maximumValueLabel: {
                Text("\(range.upperBound)")
            }
            .gaugeStyle(.accessoryCircular)
            .tint(Gradient(colors: [.green, .yellow, .orange, .red, .pink]))
            
            Text(labels[value - 1])
                .foregroundStyle(.secondary)
                .customFont(.caption2)
        }
    }
    
    private func simpleChart(_ values: [Double])  -> some View {
        let minValue = values.min()!
        let maxValue = values.max()!
        let minY = roundDownToPowerOfTen(minValue - 10)
        let maxY = roundUpToPowerOfTen(maxValue)

        return Chart {
            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                LineMark(
                    x: .value("Index", index),
                    y: .value("Value", value)
                )
                
                PointMark(
                    x: .value("Index", index),
                    y: .value("Value", value)
                )
                .symbol {
                    Rectangle()
                        .fill(.black)
                        .frame(width: 5, height: 5)
                 }
            }
        }
        .chartYScale(domain: minY...maxY)
        .chartXAxis(.hidden)
        .foregroundStyle(Color.yellow)
        .padding()
    }
    
    private func roundDownToPowerOfTen(_ value: Double) -> Double {
        let power = pow(10, floor(log10(value)))
        return floor(value / power) * power
    }

    private func roundUpToPowerOfTen(_ value: Double) -> Double {
        let power = pow(10, floor(log10(value)))
        return ceil(value / power) * power
    }
}
