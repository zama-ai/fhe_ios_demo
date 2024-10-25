// Copyright © 2024 Zama. All rights reserved.

import SwiftUI

#Preview {
    SecureView().gauge(value: 3, range: 1...5, title: "Sleep Quality", labels: ["Excellent", "Good", "Average", "Poor", "Awful"])
        .border(.red)
        .privateDisplayRing()
        .border(.green)
}

struct SecureView: View {
    @ObservedObject var viewModel = ViewModel()
    
    var body: some View {
        switch viewModel.data {
        case let .gauge(value, range, title, labels):
            gauge(value: value, range: range, title: title, labels: labels)
                .privateDisplayRing()

        case .int(let int):
            SecureTextView(value: int)

        case .simpleChart(let array):
            SecureChartView(values: array, kind: .lines)

        case .none:
            Color.red
        }
    }
    
    enum Kind {
        case gauge(value: Int, range: ClosedRange<Int>, title: String, labels: [String])
        case int(Double)
        case simpleChart([Double])
    }
    
    final class ViewModel: ObservableObject {
        @Published var data: Kind?
    }
}

extension SecureView {
    func gauge(value: Int, range: ClosedRange<Int>, title: String, labels: [String]) -> some View {
        VStack(spacing: 0) {
            Gauge(value: Double(value), in: Double(range.lowerBound)...Double(range.upperBound)) {
                Text(title)
            } currentValueLabel: {
                VStack(spacing: 0) {
                    Text("\(value)")
                        .font(.title2)
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
                .font(.caption2)
        }
    }
}

struct SecureTextView: View {
    let value: Double
    
    var body: some View {
        Text("\(value.formatted(.number.precision(.fractionLength(1))))")
            .privateDisplayRing()
    }
}

import Charts
struct SecureChartView: View {
    enum Kind { case lines, bars}
    let values: [Double]
    let kind: Kind
    
    var body: some View {
        Chart {
            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                switch kind {
                case .lines:
                    PointMark(
                        x: .value("Index", index),
                        y: .value("Value", value)
                    )
                    LineMark(
                        x: .value("Index", index),
                        y: .value("Value", value)
                    )
                case .bars:
                    BarMark(
                        x: .value("Index", index),
                        y: .value("Value", value)
                    )
                }
            }
        }
        .chartXAxis(.hidden)
//        .padding(4) // Chart draws some elements outside of its view
        .privateDisplayRing()
    }
}

//#Preview {
//    {
//        return PrivateTextView(vm: .init())
//    }()
//    
//    PrivateChartView(values: [6, 8, 7, 6, 6, 8, 7, 6, 9, 7], kind: .lines)
//    PrivateChartView(values: [6, 8, 7, 6, 6, 8, 7, 6, 9, 7], kind: .bars)
//}
