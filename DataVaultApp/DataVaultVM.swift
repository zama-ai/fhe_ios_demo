// Copyright © 2025 Zama. All rights reserved.

import HealthKit
import Algorithms
import SwiftUI

extension DataVaultView {
    @MainActor
    final class ViewModel: ObservableObject {
        
        @Published var weightGranted: Bool = false
        @Published var sleepGranted: Bool = false
        
        @Published var weight: [Double] = []
        @Published var weightDateRange: String = ""
        @Published var sleep: [Sleep.Night] = []
        @Published var selectedNight: Date?
        
        @AppStorage("name") var clearProfileName: String?
        @AppStorage("sex") var clearProfileSex: String?
        @AppStorage("age") var clearProfileAge: String?
        @AppStorage("interests") var clearProfileInterests: String?

        @Published var encryptedWeight: Data?
        @Published var encryptedSleep: Data?
        @Published var encryptedProfile: Data?

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
            encryptedWeight = await Storage.read(.weightList)
            encryptedSleep = await Storage.read(.sleepList)
            encryptedProfile = await Storage.read(.matrixEncryptedProfile)
            try await fetchHealthData()
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
            try await fetchHealthData()
        }
        
        func requestSleepPermission() async throws {
            guard let sleepType else { return }
            try await healthStore.requestAuthorization(toShare: [], read: [sleepType])
            try await refreshPermission()
            try await fetchHealthData()
        }
        
        func fetchHealthData() async throws {
            async let weightSamples = await getSamples(type: HKQuantityType(.bodyMass), last: 10)
            async let sleepSamples = await getSamples(type: HKCategoryType(.sleepAnalysis), last: 150)
            
            guard let weight = await weightSamples as? [HKDiscreteQuantitySample],
                  let sleep = await sleepSamples as? [HKCategorySample] else {
                assertionFailure("Samples type mismatch")
                return
            }
            
            weight.forEach(printSample)
            sleep.forEach(printSample)
            
            processSamples(weightSamples: weight, sleepSamples: sleep)
        }
        
        private func processSamples(weightSamples: [HKDiscreteQuantitySample], sleepSamples: [HKCategorySample]) {
            let cleanedWeight: [Double] = weightSamples.map { $0.quantity.doubleValue(for: .gramUnit(with: .kilo)) }
            
            let dateInterval: String = {
                if let start = weightSamples.first?.startDate,
                   let end = weightSamples.last?.endDate {
                    return "\(start.formatted(.dateTime.day().month().year())) - \(end.formatted(.dateTime.day().month().year()))"
                    
                }
                return ""
            }()
            
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
            
            Task {
                weight = cleanedWeight
                weightDateRange = dateInterval
                sleep = nights
                selectedNight = nights.first?.date
            }
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
    }
}

//import concrete_ml_extensionsFFI
// MARK: - Profile -
extension DataVaultView.ViewModel {
    func encryptProfile() async throws {
        print(#function)
        //sayHello()
    }
    
    func deleteProfile() async throws {
        print(#function)
        try await Storage.deleteFromDisk(.matrixEncryptedProfile)
        try await loadFromDisk()
    }
}

// MARK: - ENCRYPTION -
extension DataVaultView.ViewModel {
    func encryptSleep() async throws {
        try await ensureKeysExist()
        
        guard let selectedNight, let data = sleep.first(where: { $0.date == selectedNight }) else {
            print("can't find a night to encrypt")
            return
        }
        
        let example: [[Int]] = data.samples.map {
            [$0.level.rawValue, $0.start, $0.end]
        }
        
        if let pk {
            let list = try CompactCiphertextList(encrypting: example, publicKey: pk)
            let listData = try list.toData()
            try await Storage.write(.sleepList, data: listData)
            encryptedSleep = listData
        }
    }
    
    func deleteSleep() async throws {
        try await Storage.deleteFromDisk(.sleepList)
        try? await Storage.deleteFromDisk(.sleepScore)
        
        try await loadFromDisk()
    }
    
    func useFakeSleep() {
        let night = Sleep.Night.fake
        sleep = [night]
        selectedNight = night.date
    }

    func useFakeBadSleep() {
        let night = Sleep.Night.fakeBad
        sleep = [night]
        selectedNight = night.date
    }

    func useLargeFakeSleep() {
        let night = Sleep.Night.fakeLarge
        sleep = [night]
        selectedNight = night.date
    }
    
    func useFakeWeight() {
        weight = [63, 70, 73, 68, 71]
        weightDateRange = "Fake weights"
    }
    
    func encryptWeight() async throws {
        try await ensureKeysExist()
        
        if let pk {
            let biggerInts = weight.map { Int( $0 * 10) } // 10x so as to have 1 fractional digit precision
            let array = try FHEUInt16Array(encrypting: biggerInts, publicKey: pk)
            let arrayData = try array.toData()
            try await Storage.write(.weightList, data: arrayData)
            encryptedWeight = arrayData
        }
    }
    
    func deleteWeight() async throws {
        try await Storage.deleteFromDisk(.weightList)
        try? await Storage.deleteFromDisk(.weightAvg)
        try? await Storage.deleteFromDisk(.weightMin)
        try? await Storage.deleteFromDisk(.weightMax)
        
        try await loadFromDisk()
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
