// Copyright © 2024 Zama. All rights reserved.

import HealthKit

struct HealthData {
    let bodyMass: [Int] // kg
    let sleep: [Int]    // minutes
    
    static let empty = HealthData(bodyMass: [], sleep: [])
}

final class HealthViewModel: ObservableObject {
    static let shared = HealthViewModel()
    private init() {}

    @Published var data: HealthData = .empty
    
    var healthStore: HKHealthStore = { HKHealthStore() }()
        
    let sampleTypes: Set<HKSampleType> = [
        HKQuantityType(.bodyMass),      // HKDiscreteQuantitySample
        HKCategoryType(.sleepAnalysis)  // HKCategorySample
    ]
    
    func isAllowed() async throws -> Bool {
        let ok = try await healthStore.statusForAuthorizationRequest(toShare: [], read: sampleTypes)
        return ok == .unnecessary
    }
    
    func fetchHealthData() {
        Task {
            let weights = await getDiscreteSampleMeasuments(last: 10, type: HKQuantityType(.bodyMass))
            
            weights.forEach(printSample)
            
            let displayWeights = weights.map {
                let double = $0.quantity.doubleValue(for: .gramUnit(with: .kilo))
                return Int(double.rounded())
            }
            
            encryptIntegers(displayWeights)
            
//            sampleTypes.forEach {
//                getSamples(type: $0)
//            }
            
            let result = HealthData(bodyMass: displayWeights.reversed(),
                                    sleep: [6, 8, 7, 6, 6, 8, 7, 6, 9, 7])
            Task { @MainActor in
                data = result
            }
        }
    }
    
    func encryptIntegers(_ integers: [Int]) {
//        let key = HKEncryptionKey(rawValue: "12345678901234567890123456789012")!
//        let encrypted = HKEncryptedData(integers: integers, using: key)
//        return encrypted.data
    }
    
    func getDiscreteSampleMeasuments(last: Int, type: HKQuantityType) async -> [HKDiscreteQuantitySample] {
        await withCheckedContinuation { continuation in
            let sortLastFirst = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

            let query = HKSampleQuery(sampleType: type,
                                      predicate: nil,
                                      limit: last,
                                      sortDescriptors: [sortLastFirst])
            { query, samples, error in
                if let error {
                    print("error fetching: ", error.localizedDescription)
                    continuation.resume(returning: [])
                } else {
                    guard let items = (samples ?? []) as? [HKDiscreteQuantitySample] else {
                        continuation.resume(returning: [])
                        return
                    }
                    
                    continuation.resume(returning: items)
                }
            }
            healthStore.execute(query)
        }
    }

    func getSamples(type: HKSampleType) {
        let sortByDate = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        let query = HKSampleQuery(sampleType: type,
                                  predicate: nil,
                                  limit: 100,
                                  sortDescriptors: [sortByDate]) { query, samples, error in
            if let error {
                print("Error", error)
                return
            }
            
            if let samples {
                DispatchQueue.main.async { [weak self] in
                    print("\(type): \(samples.count) items")
                    samples.forEach {
                        self?.printSample($0)
                    }
                }
            }
        }
        
        healthStore.execute(query)
    }
    
    func printSample(_ sample: HKSample) {
        switch sample {
        case let bodyMass as HKDiscreteQuantitySample where sample.sampleType == HKQuantityType(.bodyMass):
            let double = bodyMass.quantity.doubleValue(for: .gramUnit(with: .kilo))
            let rounded = Int(double.rounded())
            print("bodyMass: ", sample.startDate.formatted(), bodyMass.quantity, double, rounded)
            
        case let sleep as HKCategorySample where sample.sampleType == HKCategoryType(.sleepAnalysis):
            let duration = sleep.endDate.timeIntervalSince(sample.startDate)
            let value = sleep.value
            print("sleep:\t\(sample.startDate.formatted())\t\(duration)\t\(value)")

        case _:
            print("⚠️ Unrecognized type \(sample.sampleType) \(type(of: sample))")
        }
    }
}
