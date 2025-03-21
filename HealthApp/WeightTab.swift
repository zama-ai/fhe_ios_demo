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
                if vm.samplesAvailable {
                    AsyncButton("Select Encrypted Data") {
                        await vm.selectSample()
                    }
                } else {
                    OpenAppButton(.zamaDataVault(tab: .weight))
                }

                CustomBox("Trend") {
                    Group {
                        if let url = vm.selection?.url {
                            FilePreview(url: url)
                        } else {
                            NoDataBadge()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                CustomBox("Statistics") {
                    let list = zip(["Min", "Max", "Average"], [vm.result?.min, vm.result?.max, vm.result?.avg])
                    HStack(spacing: 16) {
                        ForEach(Array(list), id: \.0) { label, value in
                            statCell(url: value, name: label)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .overlay {
                        if let status = vm.status {
                            AsyncStatus(status)
                        } else if vm.result == nil {
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
        typealias Selection = (url: URL, data: Data)
        typealias Result = (min: URL, max: URL, avg: URL)
        private let input: Storage.File = .weightList
        private let output: [Storage.File] = [.weightMin, .weightMax, .weightAvg]
        private let serverTask: Network.ServerTask = .weight_stats

        @Published var samplesAvailable: Bool
        @Published var selection: Selection?
        @Published var result: Result?
        @Published var status: ActivityStatus?

        init() {
            self.samplesAvailable = false
            self.selection = nil
        }
        
        func refreshFromDisk() {
            Task {
                let foundSamples = await Storage.read(input)
                self.samplesAvailable = foundSamples != nil
                // TODO: ensure current selection is present in samplesAvailable
                
                let input = await loadSelection()
                
                if input != nil,
                   let _ = await Storage.read(.weightMin),
                   let _ = await Storage.read(.weightMax),
                   let _ = await Storage.read(.weightAvg)
                {
                    result = (min: Storage.url(for: .weightMin),
                              max: Storage.url(for: .weightMax),
                              avg: Storage.url(for: .weightAvg))
                }
                
                if input == nil {
                    // Cleanup. Input == nil and Output != nil means corruption;
                    // Input might have been deleted in DataVault.
                    print("nil input, deleting output")
                    try await Storage.deleteFromDisk(.weightMin)
                    try await Storage.deleteFromDisk(.weightMax)
                    try await Storage.deleteFromDisk(.weightAvg)
                    self.uploadedSampleHash = nil
                    self.uploadedSampleTaskID = nil
                    self.status = nil
                    result = nil
                }
            }
        }
        
        func selectSample() async {
            guard let data = await Storage.read(input) else {
                return
            }
            
            self.selection = (Storage.url(for: input), data)
            
            do {
                self.status = .progress("Uploading Server Key…")
                let uid = try await uploadServerKey()
                
                self.status = .progress("Uploading Encrypted Data…")
                let taskID = try await uploadSample(data, uid: uid)
                
                self.status = .progress("Analyzing weight statistics…")
                self.result = try await getServerResult(uid: uid, taskID: taskID)
                
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
        
        private func getServerResult(uid: Network.UID, taskID: Network.TaskID) async throws -> Result {
            let result = try await Network.shared.getWeightResult(taskID: taskID, uid: uid)
            try await Storage.write(.weightMin, data: result.min)
            try await Storage.write(.weightMax, data: result.max)
            try await Storage.write(.weightAvg, data: result.avg)

            try await Storage.write(.weightMin, data: result.min, suffix: "preview")
            try await Storage.write(.weightMax, data: result.max, suffix: "preview")
            try await Storage.write(.weightAvg, data: result.avg, suffix: "preview")

            return Result(min: Storage.url(for: .weightMin),
                          max: Storage.url(for: .weightMax),
                          avg: Storage.url(for: .weightAvg))
        }
        
        // Note: ServerKey hash and uid are SHARED between Sleep and Weight Tabs
        @UserDefaultsStorage(key: "SHARED.uploadedKeyHash", defaultValue: nil)
        private var uploadedKeyHash: String?
        
        @UserDefaultsStorage(key: "SHARED.uploadedKeyUID", defaultValue: nil)
        private var uploadedKeyUID: Network.UID?
        
        @UserDefaultsStorage(key: "WEIGHT.uploadedSampleHash", defaultValue: nil)
        private var uploadedSampleHash: String?

        @UserDefaultsStorage(key: "WEIGHT.uploadedSampleTaskID", defaultValue: nil)
        private var uploadedSampleTaskID: Network.TaskID?
                
        private func loadSelection() async -> Selection? {
            let data = await Storage.read(input)
            if let data {
                self.selection = (url: Storage.url(for: input), data: data)
            } else {
                self.selection = nil
            }
            return self.selection
        }
    }
}
