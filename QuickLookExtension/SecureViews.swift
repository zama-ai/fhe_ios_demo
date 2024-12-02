// Copyright © 2024 Zama. All rights reserved.

import SwiftUI
import Charts

#Preview {
    let vm = SecureView.ViewModel(data: .gauge(value: 3, range: 1...5, title: "Sleep Quality", labels: ["Excellent", "Good", "Average", "Poor", "Awful"]))
    SecureView(viewModel: vm)
        .border(.red)
        .border(.green)
}

struct SecureView: View {
    @ObservedObject var viewModel = ViewModel()
    
    final class ViewModel: ObservableObject {
        @Published var data: Kind?
        
        init(data: SecureView.Kind? = nil) {
            self.data = data
        }
    }
    
    enum Kind {
        case text(value: Double)
        case gauge(value: Int, range: ClosedRange<Int>, title: String, labels: [String])
        case simpleChart([Double])
    }

    var body: some View {
        Group {
            switch viewModel.data {
            case let .gauge(value, range, title, labels):
                gauge(value: value, range: range, title: title, labels: labels)
                
            case .text(let value):
                text(value: value)
                
            case .simpleChart(let values):
                simpleChart(values)
                
            case .none:
                Color.red
            }
        }.privateDisplayRing()
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
        Chart {
            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                PointMark(
                    x: .value("Index", index),
                    y: .value("Value", value)
                )
                LineMark(
                    x: .value("Index", index),
                    y: .value("Value", value)
                )
            }
        }
        .chartXAxis(.hidden)
    }
}
