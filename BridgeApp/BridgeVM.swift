// Copyright © 2024 Zama. All rights reserved.

import HealthKit

struct HealthData {
//    struct SleepSample {
//        let start: Date
//        let end: Date
//        let value: Int
//    }
    let weight: [Double] // Kg
    let sleep: [Int] // Sleep level (1-5)
    
    static let empty = HealthData(weight: [], sleep: [])
}

@MainActor
final class BridgeViewModel: ObservableObject {
    static let shared = BridgeViewModel()
    
    @Published var clearData: HealthData = .empty
    @Published var encryptedWeight: Data?
    @Published var encryptedSleep: Data?

    private var ck: ClientKey?
    private var pk: PublicKeyCompact?
    private var sk: ServerKeyCompressed?

    lazy var healthStore: HKHealthStore = { HKHealthStore() }()
    let sampleTypes: Set<HKSampleType> = [
        HKQuantityType(.bodyMass),      // HKDiscreteQuantitySample
        HKCategoryType(.sleepAnalysis)  // HKCategorySample
    ]
    
    func loadFromDisk() async throws {
        encryptedWeight = try await Storage.read(.weightList)
    }
    
    func isAllowed() async throws -> Bool {
        let ok = try await healthStore.statusForAuthorizationRequest(toShare: [], read: sampleTypes)
        return ok == .unnecessary
    }
    
    func fetchHealthData() {
        Task {
            async let weightSamples = await getSamples(type: HKQuantityType(.bodyMass), last: 10)
            async let sleepSamples = await getSamples(type: HKCategoryType(.sleepAnalysis), last: 20) 
            
            guard let weight = await weightSamples as? [HKDiscreteQuantitySample],
                  let sleep = await sleepSamples as? [HKCategorySample] else {
                assertionFailure("Samples type mismatch")
                return
            }
            
            // 28/12/13 22h30 -> 28/12/13 23h00 : sleep level 5
            weight.forEach(printSample)
            sleep.forEach(printSample)

            Task { @MainActor in
                clearData = HealthData(weight: weight.map { $0.quantity.doubleValue(for: .gramUnit(with: .kilo)) },
                                       sleep: sleep.map { $0.value })
            }
        }
    }
        
    func getSamples(type: HKSampleType, last: Int) async -> [HKSample] {
        await withCheckedContinuation { continuation in
            let mostRecents = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

            let query = HKSampleQuery(sampleType: type,
                                      predicate: nil,
                                      limit: last,
                                      sortDescriptors: [mostRecents]) { query, samples, error in
                if let error {
                    print("error fetching: ", error.localizedDescription)
                    continuation.resume(returning: [])
                } else {
                    continuation.resume(returning: samples?.reversed() ?? [])
                }
            }
            healthStore.execute(query)
        }
    }

    func printSample(_ sample: HKSample) {
        switch sample {
        case let weight as HKDiscreteQuantitySample where sample.sampleType == HKQuantityType(.bodyMass):
            let double = weight.quantity.doubleValue(for: .gramUnit(with: .kilo))
            let rounded = Int(double.rounded())
            print("weight: ", sample.startDate.formatted(), weight.quantity, double, rounded)
            
        case let sleep as HKCategorySample where sample.sampleType == HKCategoryType(.sleepAnalysis):
            let duration = sleep.endDate.timeIntervalSince(sample.startDate)
            let value = sleep.value
            print("sleep:\t\(sample.startDate.formatted())\t\(duration)\t\(value)")

        case _:
            print("⚠️ Unrecognized type \(sample.sampleType) \(type(of: sample))")
        }
    }
}

// MARK: - ENCRYPTION -
extension BridgeViewModel {
    func encryptWeight() async throws {
        try await ensureKeysExist()
        
        if let ck {
            let enc = try FHEUInt16(encrypting: 42, clientKey: ck)
            try await enc.writeToDisk(.ageIn)
        }
        
        if let pk {
            let biggerInts = clearData.weight.map { Int( $0 * 10) } // 10x so as to have 1 fractional digit precision
            let array = try FHEUInt16Array(encrypting: biggerInts, publicKey: pk)
            let arrayData = try array.toData()
            try await Storage.write(.weightList, data: arrayData)
            encryptedWeight = arrayData
        }
    }

    func deleteWeight() async throws {
        try await Storage.deleteFromDisk(.weightList)
        encryptedWeight = nil
    }

    private func ensureKeysExist() async throws {
        if ck == nil {
            if let saved = try? await ClientKey.readFromDisk(.clientKey) {
                ck = saved
            } else {
                let new = try ClientKey.generate()
                try await new.writeToDisk(.clientKey)
                ck = new
            }
        }
        
        if pk == nil, let ck {
            if let saved = try? await PublicKeyCompact.readFromDisk(.publicKey) {
                pk = saved
            } else {
                let new = try PublicKeyCompact(clientKey: ck)
                try await new.writeToDisk(.publicKey)
                pk = new
            }
        }
        
        if sk == nil, let ck {
            if let saved = try? await ServerKeyCompressed.readFromDisk(.serverKey) {
                sk = saved
            } else {
                let new = try ServerKeyCompressed(clientKey: ck)
                try await new.writeToDisk(.serverKey)
                sk = new
            }
        }
    }
}
