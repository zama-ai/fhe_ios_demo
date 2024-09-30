// Copyright © 2024 Zama. All rights reserved.

import Foundation

let rootURL = URL(string: "http://localhost:8888")!
test_program()

func test_program() {
    // FIXME: get real serverKey and encryptedInput
    let serialized_evaluation_keys = Data("fixme: some encrypted input".utf8)
    let encrypted_input = Data("fixme: some encrypted input".utf8)

    Task {
        do {
            let uid = try await uploadServerKey(serialized_evaluation_keys)
            print("This user ID is \(uid)")

            let prediction = try await launchFHEComputation(uid: uid,
                                                            encryptedInput: encrypted_input)
            print("Prediction: \n\(prediction)")
        } catch {
            print("❌ ERROR: ", error)
        }

        print("Successful end")
        exit(0)
    }

    RunLoop.main.run()  // Prevent script from exiting immediately (for command-line Swift scripts)
}

func uploadServerKey(_ serverKey: Data) async throws -> String {
    let res = try await sendRequest(.multipartPOST(root: rootURL,
                                                   path: "/add_key",
                                                   json: [:],
                                                   file: (name: "key", data: serverKey)))

    if let json = try JSONSerialization.jsonObject(with: res, options: []) as? [String: Any],
        let uid = json["uid"] as? String {
        return uid
    } else {
        throw NetworkingError.resultParsingFailed
    }
}

func launchFHEComputation(uid: String, encryptedInput: Data) async throws -> String {
    let res = try await sendRequest(.multipartPOST(root: rootURL,
                                                   path: "/compute",
                                                   json: ["uid": uid],
                                                   file: ("model_input", encryptedInput)))

    if let result = String(data: res, encoding: .utf8) {
        return result
    } else {
        throw NetworkingError.resultParsingFailed
    }
}

// MARK: - Networking Helpers -

func sendRequest(_ request: URLRequest, session: URLSession = .shared) async throws -> Data {
    let (data, response) = try await session.data(for: request)
    guard let response = response as? HTTPURLResponse else {
        throw NetworkingError.nonHTTPResponse
    }

    guard response.statusCode == 200 else {
        throw NetworkingError.invalidHTTPCode(code: response.statusCode)
    }

    return data
}

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

    var errorDescription: String? {
        switch self {
        case .jsonSerializationFailed(let details): "Error serializing JSON \(details.localizedDescription)"
        case .nonHTTPResponse: "Response is not HTTP"
        case .invalidHTTPCode(let code): "Request failed with status code: \(code)"
        case .resultParsingFailed: "Failed to parse response"
        }
    }
}
