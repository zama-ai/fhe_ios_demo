// Copyright © 2024 Zama. All rights reserved.

import Foundation

final class Network {
    struct StatsResponse: Codable {
        let min: Data
        let max: Data
        let avg: Data
    }
    
    static let shared = Network()
    private init() {}

    private let rootURL = URL(string: "http://54.155.5.123")!
    
    /// - Returns: uid of the server key, for server caching purposes. No need to re-upload it every time, since it is somewhat heavy (about 27 MB).
    func uploadServerKey(_ sk: Data) async throws -> String {
        let res = try await sendRequest(.multipartPOST(root: rootURL,
                                                       path: "/add_key",
                                                       json: [:],
                                                       file: (name: "key", data: sk)))

        if let json = try JSONSerialization.jsonObject(with: res, options: []) as? [String: Any],
            let uid = json["uid"] as? String {
            return uid
        } else {
            throw NetworkingError.resultParsingFailed
        }
    }
    
    /// - Returns: FheUint16 min, max and avg of the list of weights. Clear values have to be divided by 10.
    func getWeightStats(uid: String, encryptedWeights: Data) async throws -> (min: Data, max: Data, avg: Data) {
        let res = try await sendRequest(.multipartPOST(root: rootURL,
                                                       path: "/weight_stats",
                                                       json: ["uid": uid],
                                                       file: ("input", encryptedWeights)))
        
        let obj = try JSONDecoder().decode(StatsResponse.self, from: res)
        return (obj.min, obj.max, obj.avg)
    }

    /// - Returns: FheUint8 score between 1 and 5. 1 is best, 5 is bad.
    func getSleepQuality(uid: String, encryptedSleeps: Data) async throws -> Data {
        let res = try await sendRequest(.multipartPOST(root: rootURL,
                                                       path: "/sleep_quality",
                                                       json: ["uid": uid],
                                                       file: ("input", encryptedSleeps)))
        
        return res
    }

    
    // MARK: - Helpers -
    private func sendRequest(_ request: URLRequest, session: URLSession = .shared) async throws -> Data {
        print("🌐 \(request.httpMethod ?? "-") /\(request.url?.lastPathComponent ?? "-") 🔄 (\(request.url?.absoluteString ?? "-"))")
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw NetworkingError.nonHTTPResponse
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
    static func multipartPOST(root: URL, path: String, json: [String: Any], file: (name: String, data: Data)) throws -> URLRequest {
        let url = root.appending(path: path)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        // Create multipart content
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        var body = Data()

        // Add JSON part
        if !json.isEmpty {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)

            if let inlineable = json.first, json.count == 1 {
                body.append("Content-Disposition: form-data; name=\"\(inlineable.key)\"\r\n\r\n".data(using: .utf8)!)
                body.append("\(inlineable.value)".data(using: .utf8)!)
            } else {
                let jsonData = try JSONSerialization.data(withJSONObject: json, options: [])
                body.append("Content-Disposition: form-data; name=\"json\"\r\n".data(using: .utf8)!)
                body.append("Content-Type: application/json\r\n\r\n".data(using: .utf8)!)
                body.append(jsonData)
            }

            body.append("\r\n".data(using: .utf8)!)
        }

        // Add file part
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(file.name)\"; filename=\"\(file.name)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        body.append(file.data)
        body.append("\r\n".data(using: .utf8)!)

        // End the boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body
        return request
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
