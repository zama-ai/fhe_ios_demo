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
                if vm.allSamples.isEmpty {
                    OpenAppButton(.zamaDataVault(tab: .sleep))
                } else if let sample = vm.selectedSample {
                    Button(action: {
                        path.append(.calendar)
                    }) {
                        Text("\(sample.date.formatted(date: .numeric, time: .omitted))")
                            .frame(maxWidth: .infinity)
                            .overlay(alignment: .trailing) {
                                Image(systemName: "chevron.down")
                                    .padding()
                            }
                    }
                } else {
                    Button("Select Encrypted Data") {
                        path.append(.calendar)
                    }
                }

                CustomBox("Sleep Phase") {
                    if let url = vm.selectedSample?.url {
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
                        
                        ZamaCalendar(covering: vm.samplesInterval ?? Calendar.current.dateInterval(of: .month, for: .now)!,
                                     selection: $selectedDate,
                                     canSelect: { item in vm.allSamples.contains { $0.date == item } })
                    }
                    .background(Color.zamaYellowLight)
                    .onChange(of: selectedDate) {
                        Task {
                            try await Task.sleep(for: .seconds(0.1))
                            path = []
                            if let selectedDate {
                                await vm.onDateSelected(date: selectedDate)
                            }
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
        typealias Selection = (date: Date, url: URL, data: Data)
        typealias Sample = (date: Date, url: URL)
        private let input: Storage.File = .sleepList
        private let output: Storage.File = .sleepScore
        private let serverTask: Network.ServerTask = .sleep_quality

        @Published var allSamples: [Sample] = []
        @Published var selectedSample: Selection?
        @Published var samplesInterval: DateInterval?
        @Published var result: URL?
        @Published var status: ActivityStatus?

        func refreshFromDisk() {
            Task {
                do {
                    try readSamplesFromDisk()
                                        
//                    if selectedSample != nil,
//                       let _ = await Storage.read(output)
//                    {
//                        result = Storage.url(for: output)
//                    }
                    
//                    if selectedSample == nil {
//                        // Cleanup. Input == nil and Output != nil means corruption;
//                        // Input might have been deleted in DataVault.
//                        print("nil input, deleting output")
//                        try await Storage.deleteFromDisk(output)
//                        self.uploadedSampleHash = nil
//                        self.uploadedSampleTaskID = nil
//                        self.status = nil
//                        result = nil
//                    }
                } catch {
                    print(error)
                }
            }
        }
        
        private func readSamplesFromDisk() throws {
            let nightURLs = try Storage.listEncryptedFiles(matching: .sleepList)
            let samples = nightURLs.compactMap { url in
                if let date = Storage.date(from: url.lastPathComponent) {
                    return (date, url)
                } else {
                    print("Error parsing date from URL: \(url)")
                    return nil
                }
            }
            self.allSamples = samples
            
            let dates = samples.map(\.0)
            if let min = dates.min(), let max = dates.max() {
                self.samplesInterval = DateInterval(start: min, end: max)
            }
        }

        func onDateSelected(date: Date) async {
            guard let nightFileURL = allSamples.first(where: { $0.date == date })?.url,
                  let data = await Storage.read(nightFileURL) else {
                return
            }
            
            print("####", date, nightFileURL)
            self.selectedSample = (date, nightFileURL, data)
            self.result = nil
            
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
        @UserDefaultsStorage(key: "v9_SHARED.uploadedKeyHash", defaultValue: nil)
        private var uploadedKeyHash: String?
        
        @UserDefaultsStorage(key: "v9_SHARED.uploadedKeyUID", defaultValue: nil)
        private var uploadedKeyUID: Network.UID?
        
        @UserDefaultsStorage(key: "v9_SLEEP.uploadedSampleHash", defaultValue: nil)
        private var uploadedSampleHash: String?

        @UserDefaultsStorage(key: "v9_SLEEP.uploadedSampleTaskID", defaultValue: nil)
        private var uploadedSampleTaskID: Network.TaskID?
    }
}
