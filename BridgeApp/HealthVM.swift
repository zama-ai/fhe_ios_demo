// Copyright © 2024 Zama. All rights reserved.

import HealthKit

struct HealthData {
    let sex: String?
    let age: Int?
    let blood: String?
    let wheelChair: Bool?
    
    let bodyMass: [Int] // kg
    let heartRate: [Int] // BPM
    let sleep: [Int] // minutes
    let energyBurned: [Int] // kcal
    let exercice: [Int] // minutes
    
    static let empty = HealthData(sex: nil, age: nil, blood: nil, wheelChair: nil, bodyMass: [], heartRate: [], sleep: [], energyBurned: [], exercice: [])
}

final class HealthViewModel: ObservableObject {
    static let shared = HealthViewModel()
    private init() {}

    @Published var data: HealthData = .empty
    
    var healthStore: HKHealthStore = { HKHealthStore() }()
    
    let permissions: Set<HKObjectType> = [
        HKCharacteristicType(.biologicalSex),
        HKCharacteristicType(.dateOfBirth),
        HKCharacteristicType(.bloodType),
        HKCharacteristicType(.wheelchairUse),
        
        HKQuantityType(.bodyMass),
        HKQuantityType(.restingHeartRate),
        HKCategoryType(.sleepAnalysis),
        HKQuantityType(.oxygenSaturation),
        HKQuantityType(.activeEnergyBurned),
        HKQuantityType(.appleExerciseTime),
    ]
    
    let sampleTypes: Set<HKObjectType> = [
        HKQuantityType(.bodyMass),
        HKQuantityType(.restingHeartRate),
        HKCategoryType(.sleepAnalysis),
        HKQuantityType(.oxygenSaturation),
        HKQuantityType(.activeEnergyBurned),
        HKQuantityType(.appleExerciseTime),
    ]
    
    func fetchHealthData() {
        let info = getUserInfo()
        Task {
            async let weights = await getDiscreteSampleMeasuments(type: HKQuantityType(.bodyMass),
                                                                  unit: .gramUnit(with: .kilo))
            
            async let heartRate = await getDiscreteSampleMeasuments(type: HKQuantityType(.restingHeartRate),
                                                                    unit: HKUnit.count().unitDivided(by: .minute()))

            getSamples()
            
            let result = await HealthData(sex: info.sex,
                                          age: info.age,
                                          blood: info.blood,
                                          wheelChair: info.wheelchair,
                                          bodyMass: weights.reversed(),
                                          heartRate: heartRate.reversed(),
                                          sleep: [6, 8, 7, 6, 6, 8, 7, 6, 9, 7],
                                          energyBurned: [1630, 2024, 3204, 400, 1630, 2024, 3204, 400, 2, 3],
                                          exercice: [71, 22, 43, 18, 71, 22, 43, 21, 23])
            Task { @MainActor in
                data = result
            }
        }
    }
    
    func getUserInfo() -> (sex: String?, age: Int?, blood: String?, wheelchair: Bool?) {
        let sex: String? = {
            switch try? healthStore.biologicalSex().biologicalSex {
            case .female: "Female"
            case .male: "Male"
            case .other: "Other"
            case _: nil
            }
        }()
        
        let age: Int? = {
            guard let comps = try? healthStore.dateOfBirthComponents(),
                  let birthDate = Calendar.current.date(from: comps) else {
                return nil
            }
            return Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year
        }()
        
        let blood: String? = {
            switch try? healthStore.bloodType().bloodType {
            case .aPositive: "A+"
            case .aNegative: "A-"
            case .bPositive: "B+"
            case .bNegative: "B-"
            case .abPositive: "AB+"
            case .abNegative: "AB-"
            case .oPositive: "O+"
            case .oNegative: "O-"
            case _: nil
            @unknown default: nil
            }
        }()
        
        let wheelchair: Bool? = {
            switch try! healthStore.wheelchairUse().wheelchairUse {
            case .yes: true
            case .no: false
            case _: nil
            @unknown default: nil
            }
        }()
        
        return (sex, age, blood, wheelchair)
    }
    
    func getDiscreteSampleMeasuments(type: HKQuantityType, unit: HKUnit) async -> [Int] {
        await withCheckedContinuation { continuation in
            let sortLastFirst = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

            let query = HKSampleQuery(sampleType: type,
                                      predicate: nil,
                                      limit: 10,
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
                    
                    // Debugging
//                    items.forEach {
//                        self?.processSample($0)
//                    }

                    let weights = items.map({
                        let double = $0.quantity.doubleValue(for: unit)
                        return Int(double.rounded())
                    })
                    continuation.resume(returning: weights)
                }
            }
            healthStore.execute(query)
        }
    }

    func getSamples() {
        let sampleTypes = [
            HKQuantityType(.bodyMass),          // HKDiscreteQuantitySample
            HKQuantityType(.restingHeartRate),         // HKDiscreteQuantitySample
            HKQuantityType(.oxygenSaturation),
            HKCategoryType(.sleepAnalysis),     // HKCategorySample
            HKQuantityType(.activeEnergyBurned),// HKCumulativeQuantitySample
            HKQuantityType(.appleExerciseTime)  // HKCumulativeQuantitySample
        ]
        
        sampleTypes.forEach { getSamples(type: $0) }
    }
    
    func getSamples(type: HKSampleType) {
        let sortByDate = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        let query = HKSampleQuery(sampleType: type,
                                  predicate: nil,
                                  limit: 10,
                                  sortDescriptors: [sortByDate]) { query, samples, error in
            if let error {
                print("Error", error)
                return
            }
            
            if let samples {
                DispatchQueue.main.async { [weak self] in
                    print("\(type): \(samples.count) items")
                    samples.forEach {
                        self?.processSample($0)
                    }
                }
            }
        }
        
        healthStore.execute(query)
    }
    
    func processSample(_ sample: HKSample) {
        switch sample {
        case let bodyMass as HKDiscreteQuantitySample where sample.sampleType == HKQuantityType(.bodyMass):
            let double = bodyMass.quantity.doubleValue(for: .gramUnit(with: .kilo))
            let rounded = Int(double.rounded())
            print("bodyMass: ", sample.startDate.formatted(), bodyMass.quantity, double, rounded)
            
        case let heartRate as HKDiscreteQuantitySample where sample.sampleType == HKQuantityType(.restingHeartRate):
            let bpmUnit = HKUnit.count().unitDivided(by: .minute())
            let double = heartRate.quantity.doubleValue(for: bpmUnit)
            let rounded = Int(double.rounded())
            print("heartRate: ", sample.startDate.formatted(), heartRate.quantity, double, rounded)
            
        case let oxygen as HKDiscreteQuantitySample where sample.sampleType == HKQuantityType(.oxygenSaturation):
            let double = oxygen.quantity.doubleValue(for: .percent())
            print("oxygen:\t", sample.startDate.formatted(), "\t", double)

        case let sleep as HKCategorySample where sample.sampleType == HKCategoryType(.sleepAnalysis):
            let duration = sleep.endDate.timeIntervalSince(sample.startDate)
            let value = sleep.value
            print("sleep:\t\(sample.startDate.formatted())\t\(duration)\t\(value)")

        case let energyBurned as HKCumulativeQuantitySample where sample.sampleType == HKQuantityType(.activeEnergyBurned):
            let double = energyBurned.quantity.doubleValue(for: .smallCalorie())
            let rounded = Int(double.rounded())
            print("energyBurned: ", sample.startDate.formatted(), energyBurned.quantity, double, rounded)
            
        case let exerciceTime as HKCumulativeQuantitySample where sample.sampleType == HKQuantityType(.appleExerciseTime):
            let double = exerciceTime.quantity.doubleValue(for: .minute())
            let rounded = Int(double.rounded())
            print("exerciceTime: ", sample.startDate.formatted(), exerciceTime.quantity, double, rounded)
            
        case _:
            print("⚠️ Unrecognized type \(sample.sampleType) \(type(of: sample))")
        }
    }
    
    func calculateTotalSleepTime(from samples: [HKCategorySample]) -> TimeInterval {
        samples
            .filter { $0.value == HKCategoryValueSleepAnalysis.inBed.rawValue }
            .reduce(0) { total, sample in
                total + sample.endDate.timeIntervalSince(sample.startDate)
            }
    }
    
    // MARK: - CLEANUP BELOW -
    var stepCountToday: Int = 0
    var thisWeekSteps: [Int: Int] = [1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0]
    
    func readStepCountToday() {
        let stepCountType = HKQuantityType(.stepCount)
        
        let now = Date()
        let startDate = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: now,
            options: .strictStartDate
        )
        
        let query = HKStatisticsQuery(
            quantityType: stepCountType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) {
            _, result, error in
            guard let result = result, let sum = result.sumQuantity() else {
                print("failed to read step count: \(error?.localizedDescription ?? "UNKNOWN ERROR")")
                return
            }
            
            let steps = Int(sum.doubleValue(for: HKUnit.count()))
            self.stepCountToday = steps
        }
        healthStore.execute(query)
    }
    
    func readStepCountThisWeek() {
        let stepCountType = HKQuantityType(.stepCount)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Find the start date (Monday) of the current week
        guard let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) else {
            print("Failed to calculate the start date of the week.")
            return
        }
        
        // Find the end date (Sunday) of the current week
        guard let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek) else {
            print("Failed to calculate the end date of the week.")
            return
        }
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfWeek,
            end: endOfWeek,
            options: .strictStartDate
        )
        
        let query = HKStatisticsCollectionQuery(
            quantityType: stepCountType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum, // fetch the sum of steps for each day
            anchorDate: startOfWeek,
            intervalComponents: DateComponents(day: 1) // interval to make sure the sum is per 1 day
        )
        
        query.initialResultsHandler = { _, result, error in
            guard let result = result else {
                if let error = error {
                    print("An error occurred while retrieving step count: \(error.localizedDescription)")
                }
                return
            }
            
            result.enumerateStatistics(from: startOfWeek, to: endOfWeek) { statistics, _ in
                if let quantity = statistics.sumQuantity() {
                    let steps = Int(quantity.doubleValue(for: HKUnit.count()))
                    let day = calendar.component(.weekday, from: statistics.startDate)
                    self.thisWeekSteps[day] = steps
                }
            }
        }
        
        healthStore.execute(query)
    }
}
