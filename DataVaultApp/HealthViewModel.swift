// Copyright © 2025 Zama. All rights reserved.

import HealthKit
import Algorithms
import SwiftUI

@MainActor
final class HealthViewModel: ObservableObject {
    @Published var weightGranted: Bool = false
    @Published var sleepGranted: Bool = false
    
    @Published var weight: [Double] = []
    @Published var weightDateRange: DateInterval?
    @Published var sleep: [Sleep.Night] = []
    
    @Published var encryptedWeight: Data?
    @Published var hasSleepFilesOnDisk: Bool = false
    
    @Published var weightConsoleOutput: String = ""
    @Published var sleepConsoleOutput: String = ""
    
    private var ck: ClientKey?
    private var pk: PublicKeyCompact?
    private var sk: ServerKeyCompressed?
    
    private let healthStore = HKHealthStore()
    private let sampleTypes: Set<HKSampleType> = [
        HKQuantityType(.bodyMass),
        HKCategoryType(.sleepAnalysis)
    ]
    
    private var weightType: HKQuantityType? { HKObjectType.quantityType(forIdentifier: .bodyMass) }
    private var sleepType: HKCategoryType? { HKObjectType.categoryType(forIdentifier: .sleepAnalysis) }
    
    func loadFromDisk() async throws {
        try await refreshPermission()
        
        if let weightListURL = try Storage.listEncryptedFiles(matching: .weightList).first {
            encryptedWeight = await Storage.read(weightListURL)
            weightDateRange = Storage.dateInterval(from: weightListURL.lastPathComponent)
        } else {
            encryptedWeight = nil
            weightDateRange = nil
        }

        try checkNightFilesOnDisk()
    }
    
    func checkNightFilesOnDisk() throws {
        let nightURLs = try Storage.listEncryptedFiles(matching: .sleepList)
        hasSleepFilesOnDisk = !nightURLs.isEmpty
    }
    
    func refreshPermission() async throws {
        guard let weightType, let sleepType else { return }
        weightGranted = try await healthStore.statusForAuthorizationRequest(toShare: [], read: [weightType]) == .unnecessary
        sleepGranted = try await healthStore.statusForAuthorizationRequest(toShare: [], read: [sleepType]) == .unnecessary
    }
    
    func requestWeightPermission() async throws {
        guard let weightType else { return }
        try await healthStore.requestAuthorization(toShare: [], read: [weightType])
        try await refreshPermission()
        try await fetchWeightData()
        try await encryptWeight()
    }
    
    func requestSleepPermission() async throws {
        guard let sleepType else { return }
        try await healthStore.requestAuthorization(toShare: [], read: [sleepType])
        try await refreshPermission()
        try await fetchSleepData()
    }
    
    private func fetchWeightData() async throws {
        async let weightSamples = await getSamples(type: HKQuantityType(.bodyMass), last: 100)
        
        guard let weight = await weightSamples as? [HKDiscreteQuantitySample] else {
            assertionFailure("Samples type mismatch")
            return
        }
        
        weight.forEach(printSample)
        try await process(weightSamples: weight)
    }
    
    private func fetchSleepData() async throws {
        async let sleepSamples = await getSamples(type: HKCategoryType(.sleepAnalysis), last: HKObjectQueryNoLimit)
        
        guard let sleep = await sleepSamples as? [HKCategorySample] else {
            assertionFailure("Samples type mismatch")
            return
        }
        
        sleep.forEach(printSample)
        
        let nights = process(sleepSamples: sleep)
        
        guard !nights.isEmpty else {
            self.sleepConsoleOutput += "No sleep data in Apple Health. Use 'Generate data sample' to generate mock data, or enter sleep data in Apple Health.\n\n"
            return
        }
        

        for (index, night) in nights.enumerated() {
            try await encrypt(night: night, reset: index == 0)
        }
        
        try checkNightFilesOnDisk()
    }
    
    private func process(weightSamples: [HKDiscreteQuantitySample]) async throws {
        let cleanedWeight: [Double] = weightSamples.map { $0.quantity.doubleValue(for: .gramUnit(with: .kilo)) }
        
        let dateInterval: DateInterval? = {
            if let start = weightSamples.first?.startDate,
               let end = weightSamples.last?.endDate {
                return DateInterval(start: start, end: end)
            }
            return nil
        }()
        
        weight = cleanedWeight
        weightDateRange = dateInterval
        try await encryptWeight()
    }
    
    private func process(sleepSamples: [HKCategorySample]) -> [Sleep.Night] {
        let chunks = sleepSamples.chunked(by: { a, b in
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
        
        return nights
    }
    
    private func getSamples(type: HKSampleType, last: Int) async -> [HKSample] {
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
    
    private func printSample(_ sample: HKSample) {
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
    
    // MARK: - ENCRYPTION -
    func generateFakeNights() async throws {
        // Go to bed at 11pm
        let today = Calendar.current.startOfDay(for: Date())
        let yesterdayNight = Calendar.current.date(byAdding: .hour, value: -25, to: today)!
        let nightBefore = Calendar.current.date(byAdding: .day, value: -2, to: yesterdayNight)!
        let evenBefore = Calendar.current.date(byAdding: .day, value: -3, to: nightBefore)!
        
        try await encrypt(night: .fakeRegular(date: yesterdayNight), reset: true)
        try await encrypt(night: .fakeBad(date: nightBefore), reset: false)
        try await encrypt(night: .fakeLarge(date: evenBefore), reset: false)
        try checkNightFilesOnDisk()
    }
    
    func encrypt(night: Sleep.Night, reset: Bool) async throws {
        let nightLogged = String(describing: night)
            .replacingOccurrences(of: "ZAMA_Data_Vault.Sleep.", with: "")
        
        if reset {
            self.sleepConsoleOutput = ""
        }
        self.sleepConsoleOutput += "Encrypting night…\n\n"
        self.sleepConsoleOutput += "\(nightLogged)\n\n"
        self.sleepConsoleOutput += "Crypto Params: using default TFHE-rs params\n\n"
        
        try await ensureKeysExist()
        
        let example: [[Int]] = night.samples.map {
            [$0.level.rawValue, $0.start, $0.end]
        }
        
        if let pk {
            let list = try CompactCiphertextList(encrypting: example, publicKey: pk)
            let listData = try list.toData()
            
            let suffix = Storage.suffix(for: night.date)
            try await Storage.write(.sleepList, data: listData, suffix: suffix)
            try await Storage.write(.sleepList, data: listData, suffix: "\(suffix)-preview")
            
            self.sleepConsoleOutput += "Encrypted night: \(listData.formattedSize)\n\n"
            self.sleepConsoleOutput += "Encrypted night snippet (first 100 bytes): \(listData.snippet(first: 100))\n\n"

            self.sleepConsoleOutput += "Saved at \(Storage.url(for: .sleepList))\n"
        }
    }
        
    /// Generates random weights in the range [60, 67]
    func generateFakeWeights() async throws {
        let pattern = (1...5).map { _ in
            Double.random(in: 62...65)
        }
        
        let weights: [Double] = Array(repeating: pattern, count: Int.random(in: 1...6))
            .flatMap({ $0 })
            .map({ $0 + Double.random(in: -2...2) })
        
        let weightsRounded = weights.map { Double(Int($0 * 10.0)) / 10 } // rounds to 1 decimal
        
        weight = weightsRounded
        weightDateRange = DateInterval(start: Calendar.current.date(byAdding: .month, value: -6, to: .now)!, end: .now)
        try await encryptWeight()
    }
    
    func encryptWeight() async throws {
        self.weightConsoleOutput = ""
        self.weightConsoleOutput += "Encrypting weights…\n\n"
        
        guard !weight.isEmpty else {
            self.weightConsoleOutput += "No weight data in Apple Health. Use 'Generate data sample' to generate mock data, or enter weights in Apple Health.\n\n"
            return
        }
        
        self.weightConsoleOutput += "\(weight)\n\n"
        self.weightConsoleOutput += "Crypto Params: using default TFHE-rs params\n\n"
        
        try await ensureKeysExist()
        
        if let pk, let weightDateRange {
            let biggerInts = weight.map { Int( $0 * 10) } // 10x so as to have 1 fractional digit precision
            let array = try FHEUInt16Array(encrypting: biggerInts, publicKey: pk)
            let arrayData = try array.toData()
            
            // Delete previously saved weights (eg, previous HealthKit saved records)
            for previousURL in try Storage.listEncryptedFiles(matching: .weightList) {
                try? await Storage.write(previousURL, data: nil)
            }
            
            for result in [Storage.File.weightAvg, .weightMax, .weightMin] {
                try? await Storage.deleteFromDisk(result)
                try? await Storage.deleteFromDisk(result, suffix: "preview")
            }
            
            let suffix = Storage.suffix(for: weightDateRange)
            try await Storage.write(.weightList, data: arrayData, suffix: suffix)
            encryptedWeight = arrayData
            
            self.weightConsoleOutput += "Encrypted weights: \(arrayData.formattedSize)\n\n"
            self.weightConsoleOutput += "Encrypted weights snippet (first 100 bytes): \(arrayData.snippet(first: 100))\n\n"

            self.weightConsoleOutput += "Saved at \(Storage.url(for: .weightList, suffix: suffix))\n"
        }
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
