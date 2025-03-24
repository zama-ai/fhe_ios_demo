// Copyright © 2025 Zama. All rights reserved.

import SwiftUI

#Preview {
    SleepTab()
}

struct SleepTab: View {
    @StateObject private var vm = ViewModel()
    @State private var selectedDate: Date?
    @State private var path: [Destination] = []

    enum Destination {
        case calendar
    }
    
    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 16) {
                Button("Select Date") {
                    path.append(.calendar)
                }
                if vm.samplesAvailable {
                    AsyncButton("Select Encrypted Data") {
                        await vm.selectSample()
                    }
                } else {
                    OpenAppButton(.zamaDataVault(tab: .sleep))
                }

                CustomBox("Sleep Phase") {
                    if let url = vm.selection?.url {
                        FilePreview(url: url)
                            .frame(height: 160)
                        
                        Text("""
                            **Awake**: Often brief and unnoticed.
                            **REM**: Dreaming stage, crucial for memory and emotions.
                            **Core**: Light sleep, prepares the body for deeper stages.
                            **Deep**: Restorative sleep, vital for physical recovery and growth.
                            """)
                        .fontWeight(.regular)
                        .customFont(.caption2)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    } else {
                        NoDataBadge()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                
                CustomBox("Sleep Quality") {
                    if let url = vm.result {
                        FilePreview(url: url)
                            .frame(height: 120)
                    } else {
                        if let status = vm.status {
                            AsyncStatus(status)
                                .frame(maxWidth: .infinity, minHeight: 120)
                        } else if vm.result == nil {
                            NoDataBadge()
                                .frame(maxWidth: .infinity, minHeight: 120)
                        }
                    }
                }
            }
            .navigationDestination(for: Destination.self) { value in
                switch value {
                case .calendar:
                    VStack(spacing: 0) {
                        Text("\(Image(systemName: "bed.double.fill")) Historical Data")
                            .font(.largeTitle)
                            .bold()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                        
                        ZamaCalendar(covering: Calendar.current.dateInterval(of: .year, for: .now)!,
                                     selection: $selectedDate,
                                     canSelect: { _ in true })
                    }
                    .background(Color.zamaYellowLight)
                    .onChange(of: selectedDate) {
                        Task {
                            try await Task.sleep(for: .seconds(0.1))
                            path = []
                        }
                    }
                }
            }
            .navigationTitle("Sleep Analysis")
            .padding()
            .buttonStyle(.zama)
            .background(Color.zamaYellowLight)
            .onAppearAgain {
                vm.refreshFromDisk()
            }
        }
        .tint(.black)
    }
}

extension SleepTab {
    @MainActor final class ViewModel: ObservableObject {
        typealias Selection = (url: URL, data: Data)
        private let input: Storage.File = .sleepList
        private let output: Storage.File = .sleepScore
        private let serverTask: Network.ServerTask = .sleep_quality

        @Published var samplesAvailable: Bool
        @Published var selection: Selection?
        @Published var result: URL?
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
                   let _ = await Storage.read(output)
                {
                    result = Storage.url(for: output)
                }
                
                if input == nil {
                    // Cleanup. Input == nil and Output != nil means corruption;
                    // Input might have been deleted in DataVault.
                    print("nil input, deleting output")
                    try await Storage.deleteFromDisk(output)
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
                
                self.status = .progress("Analyzing sleep quality…")
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
        
        private func getServerResult(uid: Network.UID, taskID: Network.TaskID) async throws -> URL {
            let result = try await Network.shared.getSleepResult(taskID: taskID, uid: uid)
            try await Storage.write(output, data: result)
            try await Storage.write(output, data: result, suffix: "preview")
            return Storage.url(for: output)
        }
        
        // Note: ServerKey hash and uid are SHARED between Sleep and Weight Tabs
        @UserDefaultsStorage(key: "SHARED.uploadedKeyHash", defaultValue: nil)
        private var uploadedKeyHash: String?
        
        @UserDefaultsStorage(key: "SHARED.uploadedKeyUID", defaultValue: nil)
        private var uploadedKeyUID: Network.UID?
        
        @UserDefaultsStorage(key: "SLEEP.uploadedSampleHash", defaultValue: nil)
        private var uploadedSampleHash: String?

        @UserDefaultsStorage(key: "SLEEP.uploadedSampleTaskID", defaultValue: nil)
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
