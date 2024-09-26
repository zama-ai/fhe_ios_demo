// Copyright © 2024 Zama. All rights reserved.

import Foundation

extension AnalysisView {
    struct Imported {
        let age: Data?
        let sex: Data?
        let bloodType: Data?
        let weightHistory: Data?
        let sleepHistory: Data?
        let heartRateHistory: Data?
    }
    
    struct Computed {
        let lifeExpectancy: Data
        let heartStat: Stat
    }
    
    struct Stat {
        let min: Data
        let max: Data
        let average: Data
    }

    final class ViewModel: ObservableObject {
        @Published var imported: Imported?
        @Published var computed: Computed?
        
        init(imported: Imported?, computed: Computed?) {
            self.imported = imported
            self.computed = computed
        }
        
        static let empty = ViewModel(
            imported: nil,
            computed: nil
        )

        static let fake = ViewModel(
            imported: .init(age: .random,
                            sex: .random,
                            bloodType: .random,
                            weightHistory: .random,
                            sleepHistory: .random,
                            heartRateHistory: .random
                           ),
            computed: .init(lifeExpectancy: .random,
                            heartStat: .init(min: .random, max: .random, average: .random)
                           ))
    }
}
