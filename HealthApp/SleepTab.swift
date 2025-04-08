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
            ScrollView {
                VStack(spacing: 16) {
                    if vm.allSamples.isEmpty {
                        OpenAppButton(.zamaDataVault(tab: .sleep))
                    } else if let sample = vm.selectedSample {
                        
                        let isProcessing = if case .progress = vm.status { true } else { false }
                        
                        Button(action: {
                            path.append(.calendar)
                        }) {
                            Text("\(sample.date.formatted(date: .numeric, time: .omitted))")
                                .frame(maxWidth: .infinity)
                                .overlay(alignment: .trailing) {
                                    Image(systemName: "chevron.down")
                                        .padding()
                                }
                                .overlay(alignment: .leading) {
                                    if isProcessing {
                                        ProgressView()
                                    }
                                }
                        }.disabled(isProcessing)
                        
                    } else {
                        Button("Select Encrypted Data") {
                            path.append(.calendar)
                        }
                    }
                    
                    CustomBox("Sleep Phase") {
                        if let url = vm.selectedSample?.url {
                            FilePreview(url: url)
                                .frame(height: 170)
                            
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
                        if let url = vm.resultURL {
                            FilePreview(url: url)
                                .frame(height: 130)
                        } else {
                            if let status = vm.status {
                                AsyncStatus(status)
                                    .frame(maxWidth: .infinity, minHeight: 120)
                            } else if vm.resultURL == nil {
                                NoDataBadge()
                                    .frame(maxWidth: .infinity, minHeight: 120)
                            }
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
        private let serverTask: Network.ServerTask = .sleep_quality
        
        @Published var allSamples: [Sample] = []
        @Published var selectedSample: Selection?
        @Published var samplesInterval: DateInterval?
        @Published var resultURL: URL?
        @Published var status: ActivityStatus?
        
        func refreshFromDisk() {
            Task {
                do {
                    try readSamplesFromDisk()
                    if let saved = Constants.selectedNight {
                        await onDateSelected(date: saved)
                    }
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
            
            // Hack to force QL Preview to reload…
            self.selectedSample = nil
            Constants.selectedNightInputPreviewURL = nil
            Constants.selectedNight = nil
            self.resultURL = nil
            try? await Task.sleep(for: .seconds(0.01))
            
            
            self.selectedSample = (date, nightFileURL, data)
            let suffix = Storage.suffix(for: date)
            let inputPreviewURL = Storage.url(for: .sleepList, suffix: "\(suffix)-preview")
            Constants.selectedNightInputPreviewURL = inputPreviewURL
            Constants.selectedNight = date
            Constants.selectedNightResultPreviewURL = nil
            
            // Bypass server upload if result is already on disk
            if let existing = await existingResult(for: date) {
                self.resultURL = existing.file
                Constants.selectedNightResultPreviewURL = existing.preview
                return
            }
            
            do {
                self.status = .progress("Uploading Server Key…")
                let uid = try await uploadServerKey()
                
                self.status = .progress("Uploading Encrypted Data…")
                let taskID = try await uploadSample(data, uid: uid)
                
                self.status = .progress("Analyzing sleep quality…")
                self.resultURL = try await getServerResult(uid: uid, taskID: taskID, for: date)
                self.status = nil
            } catch {
                self.status = .error(error.localizedDescription)
            }
        }
        
        func existingResult(for date: Date) async -> (file: URL, preview: URL)? {
            let suffix = Storage.suffix(for: date)
            let resultURL = Storage.url(for: .sleepScore, suffix: suffix)
            let previewURL = Storage.url(for: .sleepScore, suffix: "\(suffix)-preview")
            let data = await Storage.read(resultURL)
            return data == nil ? nil : (file: resultURL, preview: previewURL)
        }
        
        // MARK: - PRIVATE -
        
        private func uploadServerKey() async throws -> Network.UID {
            guard let keyToUpload = await Storage.read(.serverKey) else {
                throw CustomError.missingServerKey
            }
            
            let hash = keyToUpload.stableHashValue
            if hash == Constants.uploadedServerKeyHash, let uid = Constants.uploadedServerKeyUID {
                return uid // Already uploaded
            }
            
            // TODO: prevent reentrancy, if already uploading
            
            let newUID = try await Network.shared.uploadServerKey(keyToUpload, for: serverTask)
            Constants.uploadedServerKeyHash = hash
            Constants.uploadedServerKeyUID = newUID
            return newUID
        }
        
        private func uploadSample(_ sampleToUpload: Data, uid: Network.UID) async throws -> Network.TaskID {
            let hash = sampleToUpload.stableHashValue
            if hash == self.uploadedNightHash, let taskID = self.uploadedNightTaskID {
                return taskID // Already uploaded
            }
            
            // TODO: prevent reentrancy, if already uploading
            
            let taskID = try await Network.shared.startTask(serverTask, uid: uid, encrypted_input: sampleToUpload)
            self.uploadedNightHash = hash
            self.uploadedNightTaskID = taskID
            return taskID
        }
        
        private func getServerResult(uid: Network.UID, taskID: Network.TaskID, for date:Date) async throws -> URL {
            let result = try await Network.shared.getSleepResult(taskID: taskID, uid: uid)
            
            let suffix = Storage.suffix(for: date)
            let resultURL = Storage.url(for: .sleepScore, suffix: suffix)
            let resultPreviewURL = Storage.url(for: .sleepScore, suffix: "\(suffix)-preview")
            
            try await Storage.write(resultURL, data: result)
            try await Storage.write(resultPreviewURL, data: result)
            Constants.selectedNightResultPreviewURL = resultPreviewURL
            
            return Storage.url(for: .sleepScore, suffix: suffix)
        }
        
        @UserDefaultsStorage(key: "v12.uploadedNightHash", defaultValue: nil)
        private var uploadedNightHash: String?
        
        @UserDefaultsStorage(key: "v12.uploadedNightTaskID", defaultValue: nil)
        private var uploadedNightTaskID: Network.TaskID?
    }
}
