// Copyright © 2025 Zama. All rights reserved.

import Foundation

final class Network {
    struct StatusResponse: Decodable {
        let status: String
        let details: String?
    }
    
    enum ServerTask: String {
        case weight_stats, sleep_quality, ad_targeting
    }
    
    typealias UID = String
    typealias TaskID = String
    
    static let shared = Network()
    private init() {}
    
    private let rootURL = ZamaConfig.rootAPI
    
    /// - Returns: uid of the server key, for server caching purposes. No need to re-upload it every time, since it is somewhat heavy (about 27 MB).
    func uploadServerKey(_ sk: Data, for task: ServerTask) async throws -> UID {
        let res = try await sendRequest(.multipartPOST(root: rootURL,
                                                       path: "/add_key",
                                                       json: ["task_name": task.rawValue],
                                                       file: (name: "key", data: sk)))
        
        if let json = try JSONSerialization.jsonObject(with: res, options: []) as? [String: Any],
           let uid = json["uid"] as? String {
            return uid
        } else {
            throw NetworkingError.resultParsingFailed
        }
    }
    
    // MARK: - GENERIC -
    func startTask(_ task: ServerTask, uid: UID, encrypted_input: Data) async throws -> TaskID {
        let res = try await sendRequest(.multipartPOST(root: rootURL,
                                                       path: "/start_task",
                                                       json: ["task_name": task.rawValue,
                                                              "uid": uid],
                                                       file: ("encrypted_input", encrypted_input)))
        
        struct StartTaskResponse: Decodable {
            let task_id: String
        }
        
        let obj = try JSONDecoder().decode(StartTaskResponse.self, from: res)
        return obj.task_id
    }
    
    func getStatus(for task: ServerTask, id taskID: TaskID, uid: UID) async throws -> String {
        let res = try await sendRequest(.GET(root: rootURL,
                                             path: "/get_task_status",
                                             json: ["task_name": task.rawValue,
                                                    "task_id": taskID,
                                                    "uid": uid]))
        let obj = try JSONDecoder().decode(StatusResponse.self, from: res)
        return obj.status
    }
    
    /// Returns:
    /// - `Data` if result is available,
    /// - `nil` if server is still processing,
    /// - `TaskError.needToRetry` if an error occurred
    private func getTaskResult_singleShot(for task: ServerTask, taskID: TaskID, uid: String) async throws -> Data? {
        let data = try await sendRequest(.GET(root: rootURL,
                                              path: "/get_task_result",
                                              json: ["task_name": task.rawValue,
                                                     "task_id": taskID,
                                                     "uid": uid]))
        do {
            try validateStatus(for: data)
        } catch TaskError.needToWait {
            return nil
        }
        
        return data
    }
    
    /// Polling variant. Repeatedly calls `getTaskResult` until a non nil result is returned, or an error is thrown.
    private func getTaskResult_pollIfNeeded(every interval: TimeInterval, task: ServerTask, taskID: TaskID, uid: String) async throws -> Data {
        while true {
            if let result = try await getTaskResult_singleShot(for: task, taskID: taskID, uid: uid) {
                return result
            }
            
            print("  retrying in \(interval) seconds.")
            try await Task.sleep(for: .seconds( interval))
        }
    }
    
    //     `get_task_status/_result` endpoints return up to 10 different statuses, sometimes in JSON body, sometimes in HTTP Headers.
    //
    //     Moreover, data returned comes in various shapes, is not type-safe:
    //     - StreamingResponse (when returning 1 encryptedOutput, ex: sleep or ads)
    //     - JSONResponse with status/min/max/avg (when returning multiple encrypted output, ex: weight)
    //     - JSONResponse with status/details (ex: when status = started or failed)
    //     - JSONResponse with details only (ex: Internal server error)
    //   
    //    So to 'parse' it, we poke and try to find 'status', using JSONSerialization since it's untyped.
    func validateStatus(for data: Data) throws {
        let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        guard let string = json?["status"] as? String,
              let taskError = TaskError(status: string) else {
            print("Failed to determine task status. Assuming StreamingResponse, or status == success")
            return
        }
        
        throw taskError
    }
    
    // MARK: - SPECIALIZED -
    func getAdTargetingResult(taskID: TaskID, uid: UID) async throws -> Data {
        try await getTaskResult_pollIfNeeded(every: 2, task: .ad_targeting, taskID: taskID, uid: uid)
    }
    
    func getSleepResult(taskID: TaskID, uid: UID) async throws -> Data {
        try await getTaskResult_pollIfNeeded(every: 5, task: .sleep_quality, taskID: taskID, uid: uid)
    }
    
    /// - Returns: FheUint16 min, max and avg of the list of weights. Clear values have to be divided by 10.
    func getWeightResult(taskID: TaskID, uid: UID) async throws -> (min: Data, max: Data, avg: Data) {
        let data = try await getTaskResult_pollIfNeeded(every: 2, task: .weight_stats, taskID: taskID, uid: uid)
        
        struct WeightResponse: Decodable {
            let min: Data?
            let max: Data?
            let avg: Data?
        }
        
        let json = try JSONDecoder().decode(WeightResponse.self, from: data)
        guard let min = json.min, let max = json.max, let avg = json.avg else {
            throw NetworkingError.message("Result not ready yet: \(data.prettyPrinted ?? "-")")
        }
        
        return (min: min, max: max, avg: avg)
    }
    
    
    
    // MARK: - Helpers -
    private func sendRequest(_ request: URLRequest, session: URLSession = .shared) async throws -> Data {
        print("🌐 \(request.httpMethod ?? "-") /\(request.url?.lastPathComponent ?? "-") ➡️ (\(request.url?.absoluteString ?? "-"))")
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw NetworkingError.nonHTTPResponse
        }
        
        print("🌐 \(request.httpMethod ?? "-") /\(request.url?.lastPathComponent ?? "-") ⬅️")
        if let pretty = data.prettyPrinted {
            print("🌐      \(pretty)")
        }
        
        guard response.statusCode == 200 else {
            throw NetworkingError.invalidHTTPCode(code: response.statusCode)
        }
        
        print("🌐 \(request.httpMethod ?? "-") /\(request.url?.lastPathComponent ?? "-") ✅")
        return data
    }
}


// MARK: - Helpers -

extension URLRequest {
    static func GET(root: URL, path: String, json: [String: String]) throws -> URLRequest {
        var url = root.appending(path: path)
        
        // Convert JSON dictionary to a query string
        if !json.isEmpty {
            var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
            urlComponents?.queryItems = json.map { key, value in
                URLQueryItem(name: key, value: "\(value)")
            }
            if let newURL = urlComponents?.url {
                url = newURL
            }
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 300
        
        return request
    }
    
    static func multipartPOST(root: URL, path: String, json: [String: String], file: (name: String, data: Data)) throws -> URLRequest {
        let url = root.appending(path: path)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 300
        
        // Create multipart content
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        var body = Data()
        
        // Add JSON fields
        json.forEach { key, value in
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        
        // Add files fields
        [file].forEach { (fileName, fileData) in
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(fileName)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
            body.append(fileData)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        // Close the body with boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        return request
    }
}


enum TaskError: LocalizedError {
    case needToWait
    case needToRetry
    
    var errorDescription: String? {
        switch self {
        case .needToWait: "Need to wait task completion"
        case .needToRetry: "Need to restart task"
        }
    }
    
    internal enum ServerStatus: String {
        case started, reserved, queued, pending, // NEED TO WAIT
             failure, revoked, unknown, error, // NEED TO RESTART
             completed, success // RESULT AVAILABLE
    }
    
    init?(status: String) {
        guard let status = ServerStatus(rawValue: status) else {
            return nil
        }
        
        switch status {
        case .success, .completed: return nil
        case .started, .reserved, .queued: self = .needToWait
        case .pending, .failure, .revoked, .unknown, .error: self = .needToRetry
        }
    }
}

enum NetworkingError: LocalizedError {
    case jsonSerializationFailed(details: Error)
    case nonHTTPResponse
    case invalidHTTPCode(code: Int)
    case resultParsingFailed
    case message(String)
    
    var errorDescription: String? {
        switch self {
        case .jsonSerializationFailed(let details): "Error serializing JSON \(details.localizedDescription)"
        case .nonHTTPResponse: "Response is not HTTP"
        case .invalidHTTPCode(let code): "Request failed with status code: \(code)"
        case .resultParsingFailed: "Failed to parse response"
        case .message(let message): "Error: \(message)"
        }
    }
}

extension Data {
    var prettyPrinted: String? {
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: self, options: [])
            let jsonData = try JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
            
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                return jsonString
            }
            
            return nil
        } catch {
            return nil
        }
    }
}
