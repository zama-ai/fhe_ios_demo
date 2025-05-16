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
    @Published var keyManagementConsoleOutput: String = ""
    
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

    // Keys used by FHEHealthApp for its UserDefaults. DataVaultApp needs to clear these.
    private let fheHealthAppSelectedNightKey = "v12.selectedNight"
    private let fheHealthAppSelectedNightInputPreviewKey = "v12.selectedNightInputPreviewString"
    private let fheHealthAppSelectedNightResultPreviewKey = "v12.selectedNightResultPreviewString"

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
            try await encrypt(night: night, shouldLog: index == 0, isFake: false)
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
        try await encryptWeight(isFake: false)
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
//        switch sample {
//        case let weight as HKDiscreteQuantitySample where sample.sampleType == HKQuantityType(.bodyMass):
//            let double = weight.quantity.doubleValue(for: .gramUnit(with: .kilo))
//            let rounded = Int(double.rounded())
//            print("weight: ", sample.startDate.formatted(), weight.quantity, double, rounded)
//            
//        case let sleep as HKCategorySample where sample.sampleType == HKCategoryType(.sleepAnalysis):
//            let duration = sleep.endDate.timeIntervalSince(sample.startDate)
//            let value = sleep.value
//            print("sleep:\t\(sample.startDate.formatted())\t\(duration)\t\(value)")
//            
//        case _:
//            print("⚠️ Unrecognized type \(sample.sampleType) \(type(of: sample))")
//        }
    }
    
    // MARK: - ENCRYPTION -
    func generateFakeNights() async throws {
        var consoleLog = "Preparing to generate new fake sleep data...\n\n"
        self.sleepConsoleOutput = consoleLog

        let today = Calendar.current.startOfDay(for: Date())
        let yesterdayNight = Calendar.current.date(byAdding: .hour, value: -25, to: today)!
        let nightBefore = Calendar.current.date(byAdding: .day, value: -2, to: yesterdayNight)!
        let evenBefore = Calendar.current.date(byAdding: .day, value: -3, to: nightBefore)!
        
        let fakeNightsToGenerate: [(night: Sleep.Night, date: Date)] = [
            (Sleep.Night.fakeRegular(date: yesterdayNight), yesterdayNight),
            (Sleep.Night.fakeBad(date: nightBefore), nightBefore),
            (Sleep.Night.fakeLarge(date: evenBefore), evenBefore)
        ]

        consoleLog += "Deleting old FHE Health app results for consistency...\n"
        for (_, date) in fakeNightsToGenerate {
            let suffix = Storage.suffix(for: date)
            let resultFileBaseName = Storage.url(for: .sleepScore, suffix: suffix).lastPathComponent
            let resultPreviewFileBaseName = Storage.url(for: .sleepScore, suffix: "\(suffix)-preview").lastPathComponent

            do {
                try await Storage.deleteFromDisk(.sleepScore, suffix: suffix)
                consoleLog += "- Deleted \(resultFileBaseName)\n"
            } catch {
                consoleLog += "  Note: Could not delete \(resultFileBaseName) (may not exist).\n"
            }
            do {
                try await Storage.deleteFromDisk(.sleepScore, suffix: "\(suffix)-preview")
                consoleLog += "- Deleted \(resultPreviewFileBaseName)\n"
            } catch {
                consoleLog += "  Note: Could not delete \(resultPreviewFileBaseName) (may not exist).\n"
            }
        }
        consoleLog += "\n"

        var detailedEncryptionLogForFirstNight = ""

        consoleLog += "Encrypting new fake sleep data using TFHE-rs...\n"
        for (index, data) in fakeNightsToGenerate.enumerated() {
            let shouldLogDetailsThisIteration = (index == 0)
            
            if shouldLogDetailsThisIteration {
                try await encrypt(night: data.night, shouldLog: true, isFake: true)
                detailedEncryptionLogForFirstNight = self.sleepConsoleOutput
            } else {
                try await encrypt(night: data.night, shouldLog: false, isFake: true)
                guard let pkForSummary = self.pk else {
                    consoleLog += "Error: Public key not available for summarizing encryption of night \(data.date.formatted(date: .numeric, time: .omitted))\n"
                    continue
                }
                let exampleSummary: [[Int]] = data.night.samples.map { [$0.level.rawValue, $0.start, $0.end] }
                let listDataSummary = try CompactCiphertextList(encrypting: exampleSummary, publicKey: pkForSummary).toData()
                let nightDateFormatted = data.date.formatted(date: .numeric, time: .omitted)
                let savedURLSummary = Storage.url(for: .sleepList, suffix: Storage.suffix(for: data.date))
                consoleLog += "Encrypted fake night for \(nightDateFormatted): \(listDataSummary.formattedSize). Saved at \(savedURLSummary.lastPathComponent)\n"
            }
        }
        
        if !detailedEncryptionLogForFirstNight.isEmpty {
            consoleLog = detailedEncryptionLogForFirstNight + "\n" + consoleLog
        }
        consoleLog += "\n"
        self.sleepConsoleOutput = consoleLog

        try checkNightFilesOnDisk()
        consoleLog += "Checked for sleep files on disk. Has files: \(hasSleepFilesOnDisk).\n"

        UserDefaults.standard.removeObject(forKey: fheHealthAppSelectedNightKey)
        UserDefaults.standard.removeObject(forKey: fheHealthAppSelectedNightInputPreviewKey)
        UserDefaults.standard.removeObject(forKey: fheHealthAppSelectedNightResultPreviewKey)
        consoleLog += "\nCleared FHE Health app's selected night preferences from UserDefaults.\n"
        
        consoleLog += "\nFake sleep data generation complete. \nPlease open the 'FHE Health' app to observe the changes. You will need to re-select a night to trigger the re-analysis of the newly encrypted data.\n"
        
        self.sleepConsoleOutput = consoleLog
    }
    
    func encrypt(night: Sleep.Night, shouldLog: Bool, isFake: Bool) async throws {
        self.sleepEncryptedUsingFakeData = isFake

        var localLogOutput = ""

        if shouldLog {
            let nightLogged = String(describing: night)
                .replacingOccurrences(of: "ZAMA_Data_Vault.Sleep.", with: "")
        
            localLogOutput += "Encrypting night for \(night.date.formatted(date: .numeric, time: .omitted))…\n\n"
            localLogOutput += "\(nightLogged)\n\n"
            localLogOutput += "Crypto Params: using default TFHE-rs params\n\n"
        }
        
        try await ensureKeysExist()
        
        let example: [[Int]] = night.samples.map {
            [$0.level.rawValue, $0.start, $0.end]
        }
        
        if let pk {
            let list = try CompactCiphertextList(encrypting: example, publicKey: pk)
            let listData = try list.toData()
            
            let suffix = Storage.suffix(for: night.date)
            let savedURL = Storage.url(for: .sleepList, suffix: suffix)
            try await Storage.write(.sleepList, data: listData, suffix: suffix)
            try await Storage.write(.sleepList, data: listData, suffix: "\(suffix)-preview")

            if shouldLog {
                localLogOutput += "Encrypted night: \(listData.formattedSize)\n\n"
                localLogOutput += "Encrypted night snippet (first 100 bytes): \(listData.snippet(first: 100))\n\n"
                localLogOutput += "Saved at \(savedURL.lastPathComponent)\n"
            }
        } else {
            let errorMsg = "Error: Public key not available during encryption for night \(night.date.formatted(date: .numeric, time: .omitted)).\n"
            if shouldLog { localLogOutput += errorMsg }
        }

        if shouldLog {
            self.sleepConsoleOutput = localLogOutput
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
        try await encryptWeight(isFake: true)
    }
    
    func encryptWeight(isFake: Bool) async throws {
        self.weightEncryptedUsingFakeData = isFake
        
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
    
    @MainActor
    func resetTFHEKeysAndEncryptedData() async {
        let resetMessagePrefix = "Resetting Health (TFHE) keys and encrypted data...\n"
        weightConsoleOutput = resetMessagePrefix
        sleepConsoleOutput = resetMessagePrefix
        keyManagementConsoleOutput = resetMessagePrefix + "TFHE Keys are being reset. Key refresh log will be cleared.\n"

        do {
            try await Storage.deleteFromDisk(.clientKey)
            try await Storage.deleteFromDisk(.publicKey)
            try await Storage.deleteFromDisk(.serverKey)
            self.ck = nil
            self.pk = nil
            self.sk = nil
            let successMsg = "TFHE keys deleted from disk.\n"
            weightConsoleOutput += successMsg
            sleepConsoleOutput += successMsg
            keyManagementConsoleOutput += successMsg
        } catch {
            let errorMsg = "Error deleting TFHE keys: \(error.localizedDescription)\n"
            weightConsoleOutput += errorMsg
            sleepConsoleOutput += errorMsg
            keyManagementConsoleOutput += errorMsg
        }

        self.sleepEncryptedUsingFakeData = nil
        self.weightEncryptedUsingFakeData = nil

        self.encryptedWeight = nil
        self.weightDateRange = nil
        self.hasSleepFilesOnDisk = false

        do {
            let weightFiles = try Storage.listEncryptedFiles(matching: .weightList)
            for fileURL in weightFiles { try await Storage.write(fileURL, data: nil) }
            weightConsoleOutput += "All encrypted weight files deleted.\n"

            let sleepFiles = try Storage.listEncryptedFiles(matching: .sleepList)
            for fileURL in sleepFiles { try await Storage.write(fileURL, data: nil) }
            sleepConsoleOutput += "All encrypted sleep files deleted.\n"
        } catch {
            let errorMsg = "Error deleting encrypted health data files: \(error.localizedDescription)\n"
            weightConsoleOutput += errorMsg
            sleepConsoleOutput += errorMsg
            keyManagementConsoleOutput += errorMsg
        }
        
        do {
            // Delete sleep score files (and their previews)
            let sleepResultFiles = try Storage.listEncryptedFiles(matching: .sleepScore)
            for fileURL in sleepResultFiles {
                try? await Storage.write(fileURL, data: nil)
                let previewURL = fileURL.deletingPathExtension().appendingPathExtension("preview")
                try? await Storage.write(previewURL, data: nil)
            }
            sleepConsoleOutput += "All encrypted sleep result files deleted.\n"

            // Delete weight result files (and their previews)
            let weightResultFilesMin = try Storage.listEncryptedFiles(matching: .weightMin)
            for fileURL in weightResultFilesMin {
                try? await Storage.write(fileURL, data: nil)
                let previewURL = fileURL.deletingPathExtension().appendingPathExtension("preview")
                try? await Storage.write(previewURL, data: nil)
            }
            let weightResultFilesMax = try Storage.listEncryptedFiles(matching: .weightMax)
            for fileURL in weightResultFilesMax {
                try? await Storage.write(fileURL, data: nil)
                let previewURL = fileURL.deletingPathExtension().appendingPathExtension("preview")
                try? await Storage.write(previewURL, data: nil)
            }
            let weightResultFilesAvg = try Storage.listEncryptedFiles(matching: .weightAvg)
            for fileURL in weightResultFilesAvg {
                try? await Storage.write(fileURL, data: nil)
                let previewURL = fileURL.deletingPathExtension().appendingPathExtension("preview")
                try? await Storage.write(previewURL, data: nil)
            }
            weightConsoleOutput += "All encrypted weight result files deleted.\n"
        } catch {
            let errorMsg = "Error deleting encrypted FHE Health result files: \(error.localizedDescription)\n"
            weightConsoleOutput += errorMsg
            sleepConsoleOutput += errorMsg
            keyManagementConsoleOutput += errorMsg
        }

        UserDefaults.standard.removeObject(forKey: fheHealthAppSelectedNightKey)
        UserDefaults.standard.removeObject(forKey: fheHealthAppSelectedNightInputPreviewKey)
        UserDefaults.standard.removeObject(forKey: fheHealthAppSelectedNightResultPreviewKey)
        sleepConsoleOutput += "Cleared FHE Health App's UserDefaults for selected night.\n"

        weightConsoleOutput += "Health keys and data reset complete. Re-encrypt data in relevant sections.\n"
        sleepConsoleOutput += "Health keys and data reset complete. Re-encrypt data in relevant sections.\n"
        keyManagementConsoleOutput += "Health keys and data reset complete. Key refresh log also reflects this reset.\n"
    }

    @UserDefaultsStorage(key: "v12.sleepEncryptedUsingFakeData", defaultValue: nil)
    var sleepEncryptedUsingFakeData: Bool?

    @UserDefaultsStorage(key: "v12.weightEncryptedUsingFakeData", defaultValue: nil)
    var weightEncryptedUsingFakeData: Bool?

    @MainActor
    func refreshFHEServerKey() async {
        var refreshLog = "Attempting to refresh FHE server key...\n\n"
        self.keyManagementConsoleOutput = refreshLog
        var isNewClientKeyGenerated = false

        do {
            refreshLog += "Current ClientKey state: \(self.ck == nil ? "Not loaded/found locally" : "Loaded in memory")\n"
            
            if self.ck == nil {
                if let savedCk = try? await ClientKey.readFromDisk(.clientKey) {
                    self.ck = savedCk
                    refreshLog += "✅ Loaded existing ClientKey from disk.\n"
                } else {
                    isNewClientKeyGenerated = true
                    refreshLog += "ℹ️ ClientKey not found on disk. Generating new set of keys.\n"
                    let newCk = try ClientKey.generate()
                    try await newCk.writeToDisk(.clientKey)
                    self.ck = newCk
                    refreshLog += "✅ Generated and saved new ClientKey.\n"

                    self.pk = nil
                    self.sk = nil
                    try? await Storage.deleteFromDisk(.publicKey)
                    try? await Storage.deleteFromDisk(.serverKey)
                    refreshLog += "🗑️ Cleared any old PublicKey and ServerKey from disk to ensure regeneration.\n"
                }
            } else {
                refreshLog += "ℹ️ Using existing ClientKey already in memory.\n"
            }

            guard let currentCk = self.ck else {
                refreshLog += "❌ Error: ClientKey is still nil after attempting to load/generate.\n"
                self.keyManagementConsoleOutput = refreshLog
                return
            }

            refreshLog += "\n🔄 Regenerating ServerKey from current ClientKey...\n"
            let newSk = try ServerKeyCompressed(clientKey: currentCk)
            try await newSk.writeToDisk(.serverKey)
            self.sk = newSk
            refreshLog += "✅ Successfully regenerated and saved ServerKey to disk.\n"
            refreshLog += "   - ServerKey file: \(Storage.url(for: .serverKey).lastPathComponent)\n"
            
            refreshLog += "\n🔄 Regenerating PublicKey from current ClientKey...\n"
            let newPk = try PublicKeyCompact(clientKey: currentCk)
            try await newPk.writeToDisk(.publicKey)
            self.pk = newPk
            refreshLog += "✅ Successfully regenerated and saved PublicKey to disk.\n"
            refreshLog += "   - PublicKey file: \(Storage.url(for: .publicKey).lastPathComponent)\n"

            if isNewClientKeyGenerated {
                refreshLog += "\n⚠️ IMPORTANT: A new ClientKey has been generated because the old one was not found. This means:\n"
                refreshLog += "  - A new ServerKey and PublicKey have also been generated from this new ClientKey.\n"
                refreshLog += "  - Any previously encrypted health data (Sleep, Weight) using the old keys will no longer be processable by the FHE Health app with these new keys.\n"
                refreshLog += "  - You should re-encrypt your health data in the Sleep and Weight tabs after this key refresh (e.g., using 'Refresh Encrypted Data' or 'Generate data sample').\n"
            }

            refreshLog += "\n🎉 FHE key refresh complete.\n"
            refreshLog += "The FHE Health app (or other consuming apps) should now be able to use these keys from the shared storage.\n"
            refreshLog += "If the server reported a missing key, try the operation in that app again.\n"
            
            self.keyManagementConsoleOutput = refreshLog

        } catch {
            refreshLog += "\n❌ Error during FHE key refresh: \(error.localizedDescription)\n"
            self.keyManagementConsoleOutput = refreshLog
        }
    }
}
