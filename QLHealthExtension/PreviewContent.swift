// Copyright © 2025 Zama. All rights reserved.

import SwiftUI
import Charts

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
        case gauge(value: Int)
        case simpleChart([Double])
        case sleepChart([Sleep.Sample])
        
        case previewSleepQuality(quality: SleepQuality)
        case previewSleepDuration(duration: TimeInterval)
        case previewText(value: Double)
    }
    
    var body: some View {
        switch viewModel.data {
        case let .gauge(value):
            SleepQualityView(quality: SleepQuality(rawValue: value)!)
                .padding(.bottom, 8)
            
        case .text(let value):
            text(value: value)
            
        case .simpleChart(let values):
            simpleChart(values)
            
        case .sleepChart(let samples):
            SleepChartView(samples: samples)
                .padding(.bottom, 8)
            
        case .none:
            Color.red
            
        case .previewSleepQuality(let quality):
            previewSleepQuality(quality)
            
        case .previewSleepDuration(let duration):
            previewSleepDuration(duration)
            
        case .previewText(let value):
            previewText(value: value)
        }
    }
    
    private func previewSleepDuration(_ duration: TimeInterval)  -> some View {
        let totalMinutes = Int(duration) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return Text("**\(hours.formatted())** Hours **\(minutes.formatted())** Minutes")
            .fontWeight(.regular)
            .font(.custom("Telegraf-Bold", size: 22))
    }
    
    private func previewSleepQuality(_ quality: SleepQuality)  -> some View {
        Text("Sleep Quality: **\(quality.prettyTypeName)**")
            .fontWeight(.regular)
            .font(.custom("Telegraf-Bold", size: 22))
    }
    
    private func previewText(value: Double)  -> some View {
        Text("\(value.formatted(.number.precision(.fractionLength(1))))")
            .font(.custom("Telegraf-Bold", size: 22))
            .fontWeight(.bold)
    }
    
    private func text(value: Double)  -> some View {
        Color.zamaYellow
            .aspectRatio(contentMode: .fit)
            .overlay {
                Text("\(value.formatted(.number.precision(.fractionLength(1))))")
                    .customFont(.largeTitle)
                    .fontWeight(.bold)
                    .overlay(alignment: .bottom) {
                        Text("kg")
                            .customFont(.caption2)
                            .fontWeight(.light)
                            .offset(y: 12)
                    }
            }
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
        let minY = minValue - 3
        let maxY = maxValue + 2
        
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
}
