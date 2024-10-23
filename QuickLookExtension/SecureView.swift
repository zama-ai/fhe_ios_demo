// Copyright © 2024 Zama. All rights reserved.

import SwiftUI

struct SecureView: View {
    @ObservedObject var viewModel = ViewModel()
    
    var body: some View {
        switch viewModel.data {
        case .int(let int):
            SecureTextView(value: int)
            
        case .array(let array):
            SecureChartView(values: array, kind: .lines)
            
        case .none:
            Color.red
        }
    }
    
    enum Kind {
        case int(Double)
        case array([Double])
    }
    
    final class ViewModel: ObservableObject {
        @Published var data: Kind?
    }
}

struct SecureTextView: View {
    let value: Double
    
    var body: some View {
        Text("\(value.formatted(.number.precision(.fractionLength(1))))")
            .privateDataRing()
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
        .padding(4) // Chart draws some elements outside of its view
        .privateDataRing()
        .background(.clear)
    }
}

//#Preview {
//    {
//        return PrivateTextView(viewModel: .init())
//    }()
//    
//    PrivateChartView(values: [6, 8, 7, 6, 6, 8, 7, 6, 9, 7], kind: .lines)
//    PrivateChartView(values: [6, 8, 7, 6, 6, 8, 7, 6, 9, 7], kind: .bars)
//}
