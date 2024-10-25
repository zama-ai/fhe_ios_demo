// Copyright © 2024 Zama. All rights reserved.

import HealthKit
import Algorithms

struct HealthData {
    let weight: [Double] // Kg
    let sleep: [Sleep.Night]
    
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
        encryptedSleep = try await Storage.read(.sleepList)
    }
    
    func isAllowed() async throws -> Bool {
        let ok = try await healthStore.statusForAuthorizationRequest(toShare: [], read: sampleTypes)
        return ok == .unnecessary
    }
    
    func fetchHealthData() {
        Task {
            async let weightSamples = await getSamples(type: HKQuantityType(.bodyMass), last: 10)
            async let sleepSamples = await getSamples(type: HKCategoryType(.sleepAnalysis), last: 150)
            
            guard let weight = await weightSamples as? [HKDiscreteQuantitySample],
                  let sleep = await sleepSamples as? [HKCategorySample] else {
                assertionFailure("Samples type mismatch")
                return
            }
            
            weight.forEach(printSample)
            sleep.forEach(printSample)

            processSamples(weight: weight, sleep: sleep)
        }
    }
    
    func processSamples(weight: [HKDiscreteQuantitySample], sleep: [HKCategorySample]) {
        let cleanedWeight: [Double] = weight.map { $0.quantity.doubleValue(for: .gramUnit(with: .kilo)) }
        
        let chunks = sleep.chunked(by: { a, b in
            b.startDate.timeIntervalSince(a.endDate) <= 12 * 3600
        })
            
        let nights = chunks.map { samples in
            let nightStart = samples.first!.startDate
            return Sleep.Night(date: nightStart, samples: samples.map({ sample in
                Sleep.Sample(start: Int(sample.startDate.timeIntervalSince(nightStart) / 60.0),
                             end: Int(sample.endDate.timeIntervalSince(nightStart) / 60.0),
                             level: .init(rawValue: sample.value)!)
            }))
        }

        Task { @MainActor in
            clearData = HealthData(weight:cleanedWeight, sleep: nights)
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
    func encryptSleep() async throws {
        try await ensureKeysExist()
        
        let example: [[Int]] = [[0, 0, 210], [0, 240, 570], [2, 0, 30], [5, 30, 60], [3, 60, 90], [4, 90, 120], [3, 120, 150], [5, 150, 180], [2, 180, 240], [3, 240, 300], [5, 300, 330], [4, 330, 390], [2, 390, 420], [5, 420, 450], [4, 450, 510], [3, 510, 540], [5, 540, 570]]
        
        if let pk {
            let list = try CompactCiphertextList(encrypting: example, publicKey: pk)
            let listData = try list.toData()
            try await Storage.write(.sleepList, data: listData)
            encryptedSleep = listData
        }
    }
    
    func deleteSleep() async throws {
        try await Storage.deleteFromDisk(.sleepList)
        try await Storage.deleteFromDisk(.sleepResult)
        encryptedSleep = nil
    }

    func encryptWeight() async throws {
        try await ensureKeysExist()
                
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
        try await Storage.deleteFromDisk(.weightAvg)
        try await Storage.deleteFromDisk(.weightMin)
        try await Storage.deleteFromDisk(.weightMax)
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
