// Copyright © 2025 Zama. All rights reserved.

import SwiftUI

#Preview {
    WeightTab()
}

struct WeightTab: View {
    @StateObject private var vm = ViewModel()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if let samples = vm.samples {
                    Button("\(samples.interval.start.formatted(date: .numeric, time: .omitted)) - \(samples.interval.end.formatted(date: .numeric, time: .omitted))") {}
                        .allowsHitTesting(false)
                } else {
                    OpenAppButton(.zamaDataVault(tab: .weight))
                }
                
                CustomBox("Trend") {
                    Group {
                        if let url = vm.samples?.url {
                            FilePreview(url: url)
                        } else {
                            NoDataBadge()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                CustomBox("Statistics") {
                    let list = zip(["Min", "Max", "Average"], [vm.results?.min, vm.results?.max, vm.results?.avg])
                    HStack(spacing: 16) {
                        ForEach(Array(list), id: \.0) { label, value in
                            statCell(url: value, name: label)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .overlay {
                        if let status = vm.status {
                            AsyncStatus(status)
                        } else if vm.results == nil {
                            NoDataBadge()
                        }
                    }
                }
            }
            .padding()
            .navigationTitleView("Weight Analysis", icon: "scalemass.fill")
            .buttonStyle(.zama)
            .background(Color.zamaYellowLight)
            .onAppearAgain {
                vm.refreshFromDisk()
            }
        }
    }
    
    private func statCell(url: URL?, name: String) -> some View {
        VStack(spacing: 12) {
            if let url {
                FilePreview(url: url)
            } else {
                Color.clear
                    .aspectRatio(contentMode: .fit)
                    .hidden()
            }
            Text(name)
                .customFont(.subheadline)
                .opacity(url == nil ? 0 : 1)
        }
    }
}

extension WeightTab {
    @MainActor final class ViewModel: ObservableObject {
        typealias Samples = (url: URL, data: Data, interval: DateInterval)
        typealias Results = (min: URL, max: URL, avg: URL)
        private let serverTask: Network.ServerTask = .weight_stats
        
        @Published var samples: Samples?
        @Published var results: Results?
        @Published var status: ActivityStatus?
        
        func refreshFromDisk() {
            Task {
                do {
                    try await readSamplesFromDisk()
                    try await readResultsFromDisk()
                    await startUploadProcess()
                } catch {
                    status = .error(error.localizedDescription)
                }
            }
        }
        
        private func readSamplesFromDisk() async throws {
            if let fileURL = try Storage.listEncryptedFiles(matching: .weightList).first,
               let data = await Storage.read(fileURL),
               let interval = Storage.dateInterval(from: fileURL.lastPathComponent) {
                samples = (fileURL, data, interval)
            } else {
                samples = nil
            }
        }
        
        private func readResultsFromDisk() async throws {
            if samples != nil,
               let _ = await Storage.read(.weightMin),
               let _ = await Storage.read(.weightMax),
               let _ = await Storage.read(.weightAvg)
            {
                results = (min: Storage.url(for: .weightMin),
                           max: Storage.url(for: .weightMax),
                           avg: Storage.url(for: .weightAvg))
            }
        }
        
        private func cleanupResults() async throws {
            print("Deleting weight results")
            try await Storage.deleteFromDisk(.weightMin)
            try await Storage.deleteFromDisk(.weightMax)
            try await Storage.deleteFromDisk(.weightAvg)
            try await Storage.deleteFromDisk(.weightMin, suffix: "preview")
            try await Storage.deleteFromDisk(.weightMax, suffix: "preview")
            try await Storage.deleteFromDisk(.weightAvg, suffix: "preview")
            
            self.uploadedSampleHash = nil
            self.uploadedSampleTaskID = nil
            self.status = nil
            self.results = nil
        }
        
        
        private func startUploadProcess() async {
            guard let samples, results == nil else { return }
            do {
                self.status = .progress("Uploading Server Key…")
                let uid = try await uploadServerKey()
                
                self.status = .progress("Uploading Encrypted Data…")
                let taskID = try await uploadSample(samples.data, uid: uid)
                
                self.status = .progress("Analyzing weight statistics…")
                self.results = try await getServerResult(uid: uid, taskID: taskID)
                
                self.status = nil
            } catch {
                self.status = .error(error.localizedDescription)
            }
        }
        
        // MARK: - PRIVATE -
        
        private func uploadServerKey() async throws -> Network.UID {
            guard let keyToUpload = await Storage.read(.serverKey) else {
                throw CustomError.missingServerKey
            }
            
            let hash = keyToUpload.persistantHashValue
            if hash == self.uploadedKeyHash, let uid = self.uploadedKeyUID {
                return uid // Already uploaded
            }
            
            // TODO: prevent reentrancy, if already uploading
            
            let newUID = try await Network.shared.uploadServerKey(keyToUpload, for: serverTask)
            self.uploadedKeyHash = hash
            self.uploadedKeyUID = newUID
            return newUID
        }
        
        private func uploadSample(_ sampleToUpload: Data, uid: Network.UID) async throws -> Network.TaskID {
            let hash = sampleToUpload.persistantHashValue
            if hash == self.uploadedSampleHash, let taskID = self.uploadedSampleTaskID {
                return taskID // Already uploaded
            }
            
            // TODO: prevent reentrancy, if already uploading
            
            let taskID = try await Network.shared.startTask(serverTask, uid: uid, encrypted_input: sampleToUpload)
            self.uploadedSampleHash = hash
            self.uploadedSampleTaskID = taskID
            return taskID
        }
        
        private func getServerResult(uid: Network.UID, taskID: Network.TaskID) async throws -> Results {
            let result = try await Network.shared.getWeightResult(taskID: taskID, uid: uid)
            try await Storage.write(.weightMin, data: result.min)
            try await Storage.write(.weightMax, data: result.max)
            try await Storage.write(.weightAvg, data: result.avg)
            
            try await Storage.write(.weightMin, data: result.min, suffix: "preview")
            try await Storage.write(.weightMax, data: result.max, suffix: "preview")
            try await Storage.write(.weightAvg, data: result.avg, suffix: "preview")
            
            return Results(min: Storage.url(for: .weightMin),
                           max: Storage.url(for: .weightMax),
                           avg: Storage.url(for: .weightAvg))
        }
        
        // Note: ServerKey hash and uid are SHARED between Sleep and Weight Tabs
        @UserDefaultsStorage(key: "v9_SHARED.uploadedKeyHash", defaultValue: nil)
        private var uploadedKeyHash: String?
        
        @UserDefaultsStorage(key: "v9_SHARED.uploadedKeyUID", defaultValue: nil)
        private var uploadedKeyUID: Network.UID?
        
        @UserDefaultsStorage(key: "v9_WEIGHT.uploadedSampleHash", defaultValue: nil)
        private var uploadedSampleHash: String?
        
        @UserDefaultsStorage(key: "v9_WEIGHT.uploadedSampleTaskID", defaultValue: nil)
        private var uploadedSampleTaskID: Network.TaskID?
    }
}
