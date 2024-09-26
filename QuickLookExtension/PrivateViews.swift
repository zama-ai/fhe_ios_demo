// Copyright © 2024 Zama. All rights reserved.

import SwiftUI

extension PrivateTextView {
    final class ViewModel: ObservableObject {
        @Published var text: String
        
        init(text: String = "This Data is Private") {
            self.text = text
        }
    }
}

struct PrivateTextView: View {
    @ObservedObject var viewModel = ViewModel()
    
    var body: some View {
        Text(viewModel.text)
            .privateDataRing()
    }
}

import Charts
struct PrivateChartView: View {
    enum Kind { case lines, bars}
    let values: [Int]
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
        
        .frame(height: 100)
        .padding(4) // Chart draws some elements outside of its view
        .privateDataRing()
    }
}

#Preview {
    {
        return PrivateTextView(viewModel: .init())
    }()
    
    PrivateChartView(values: [6, 8, 7, 6, 6, 8, 7, 6, 9, 7], kind: .lines)
    PrivateChartView(values: [6, 8, 7, 6, 6, 8, 7, 6, 9, 7], kind: .bars)
}
