// Copyright © 2024 Zama. All rights reserved.

import Foundation

final class Network {
    static let shared = Network()
    private init() {}

    private let rootURL = URL(string: "http://localhost:8888")!
    
    // Returns: UID string
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
    
    // Returns: compute result
    func getStats(uid: String, encryptedArray: Data) async throws -> (min: Data, max: Data, avg: Data) {
        let res = try await sendRequest(.multipartPOST(root: rootURL,
                                                       path: "/compute",
                                                       json: ["uid": uid],
                                                       file: ("model_input", encryptedArray)))
        
        if let json = try JSONSerialization.jsonObject(with: res, options: []) as? [String: Any],
           let min = json["min"] as? Data,
           let max = json["max"] as? Data,
           let avg = json["avg"] as? Data {
            return (min, max, avg)
        } else {
            throw NetworkingError.resultParsingFailed
        }
    }

    
    // MARK: - Helpers -
    private func sendRequest(_ request: URLRequest, session: URLSession = .shared) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw NetworkingError.nonHTTPResponse
        }

        guard response.statusCode == 200 else {
            throw NetworkingError.invalidHTTPCode(code: response.statusCode)
        }

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
