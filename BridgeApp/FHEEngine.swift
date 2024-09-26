// Copyright © 2024 Zama. All rights reserved.

import Foundation
import TFHE

extension FHEEngine {
    static private let sharedAppGroup = "group.com.dimdl.shared"
    static private let expectedClientKeyFileName = "clientKey.uncompressed"
    static private let expectedServerKeyFileName = "serverKey.uncompressed"

    private var defaults: UserDefaults? {
        UserDefaults(suiteName: Self.sharedAppGroup)
    }
    
    enum Key: String {
        case input = "input"
        case output = "output"
    }
        
    func writeSharedData(_ value: Data?, key: Key) {
        defaults?.setValue(value, forKey: key.rawValue)
    }
    
    func readSharedData(key: Key) -> Data? {
        defaults?.value(forKey: key.rawValue) as? Data
    }
    
    func writeToDisk(_ data: Data?, fileName: String, completion: @escaping (Result<URL, Error>) -> Void) {
        // ServerKey ≈ 120MB
        // CompressedServerKey ≈ 20MB
        // UserDefaults limit at 4MB
        
        guard let sharedFolder = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.sharedAppGroup) else {
            return
        }
        
        let fileURL = sharedFolder.appendingPathComponent(fileName)

        DispatchQueue.global(qos: .background).async {
            do {
                try data?.write(to: fileURL, options: .atomic)
                DispatchQueue.main.async {
                    completion(.success(fileURL))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    static func readFile(named: String, completion: @escaping (Result<Data, Error>) -> Void) {
        guard let sharedFolder = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.sharedAppGroup) else {
            return
        }
        
        let fileURL = sharedFolder.appendingPathComponent(named)

        DispatchQueue.global(qos: .background).async {
            do {
                let data = try Data(contentsOf: fileURL)
                DispatchQueue.main.async {
                    completion(.success(data))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
}

final class FHEEngine {
    static let shared = FHEEngine()
    private init() {
        print("FHEEngine INIT")
        FHEEngine.loadClientKey { [weak self] in
            self?.client_key = $0
            print("FHEEngine ClientKey loaded")
        }
    }
    
    var client_key: OpaquePointer? // ClientKey
    private var server_key: OpaquePointer? // ServerKey
    private var public_key: OpaquePointer? // CompactPublicKey
    
    private func ensureClientServerKeysExist() {
        if client_key == nil || server_key == nil {
            generateClientServerKeys()
        }
    }
    
    private func generateClientServerKeys() {
        print(#function)
        let start = Date()
        defer {
            print(#function, "executed in \(Date().timeIntervalSince(start))s")
        }
        
        var ok: Int32
        var configBuilder: OpaquePointer? // ConfigBuilder
        var config: OpaquePointer? // Config
        
        ok = config_builder_default(&configBuilder)
        assert(ok == 0)
        
        ok = config_builder_build(configBuilder, &config);
        assert(ok == 0)
        
        ok = generate_keys(config, &client_key, &server_key)
        assert(ok == 0)
        
        persistClientKey()
        persistServerKey()
    }
    
    func persistClientKey() {
        guard let client_key else {
            print("Client key missing")
            return
        }
        
        var ok: Int32
        var buffer = DynamicBuffer(pointer: nil, length: 0, destructor: nil)
        // TODO: Optimization: use CompressedServerKey (compressed_server_key_new, compressed_server_key_decompress)
        ok = client_key_serialize(client_key, &buffer)
        assert(ok == 0)
        
        if let clientData = Self.dynamicBufferToData(buffer: buffer) {
            self.writeToDisk(clientData, fileName: Self.expectedClientKeyFileName) { result in
                switch result {
                case .success(let path): print("Client key written to disk at \(path.absoluteString)")
                case .failure(let error): print("ERROR: Client key NOT written to disk \(error)")
                }
            }
        } else {
            print("Failed to write client_key as Data")
        }
    }

    func persistServerKey() {
        guard let server_key else {
            print("Server key missing")
            return
        }
        
        var ok: Int32
        var buffer = DynamicBuffer(pointer: nil, length: 0, destructor: nil)
        // TODO: Optimization: use CompressedServerKey (compressed_server_key_new, compressed_server_key_decompress)
        ok = server_key_serialize(server_key, &buffer)
        assert(ok == 0)
        
        if let serverData = Self.dynamicBufferToData(buffer: buffer) {
            self.writeToDisk(serverData, fileName: Self.expectedServerKeyFileName) { result in
                switch result {
                case .success(let path): print("Server key written to disk at \(path.absoluteString)")
                case .failure(let error): print("ERROR: Server key NOT written to disk \(error)")
                }
            }
        } else {
            print("Failed to write server_key as Data")
        }
    }
    
    static func loadClientKey(completion: @escaping (OpaquePointer?) -> Void) {
        readFile(named: Self.expectedClientKeyFileName) { result in
            switch result {
            case .failure(let error):
                print("Client key missing \(error)")
                completion(nil)
                
            case .success(let clientData):
                var ok: Int32
                let buffer = dataToDynamicBuffer(data: clientData)
                let bufferView = DynamicBufferView(pointer: buffer.pointer, length: buffer.length)
                var clientKey: OpaquePointer?  // ClientKey

                ok = client_key_deserialize(bufferView, &clientKey)
                assert(ok == 0)
                
                completion(clientKey)
                print("Client Key loaded")
            }
        }
    }

    func loadServerKey(completion: @escaping (Int?) -> Void) {
        Self.readFile(named: Self.expectedServerKeyFileName) { result in
            switch result {
            case .failure(let error):
                print("Server key missing \(error)")
                completion(nil)
                
            case .success(let serverData):
                var ok: Int32
                let buffer = Self.dataToDynamicBuffer(data: serverData)
                let bufferView = DynamicBufferView(pointer: buffer.pointer, length: buffer.length)
                var serverKey: OpaquePointer?  // ServerKey

                ok = server_key_deserialize(bufferView, &serverKey)
                assert(ok == 0)
                
                set_server_key(serverKey)
                completion(serverData.count)
            }
        }
    }
    
    private func generatePublicKey() {
        print(#function)
        let start = Date()
        defer {
            print(#function, "executed in \(Date().timeIntervalSince(start))s")
        }
        
        let ok = compact_public_key_new(client_key, &public_key)
        assert(ok == 0)
    }
    
    func encryptInt(_ integer: UInt16) -> Data? {
        print(#function)
        let start = Date()
        defer {
            print(#function, "executed in \(Date().timeIntervalSince(start))s")
        }
        
        ensureClientServerKeysExist()
        
        var ok: Int32
        var encrypted: OpaquePointer? // FheUint16
        var buffer = DynamicBuffer(pointer: nil, length: 0, destructor: nil)
        
        ok = fhe_uint16_try_encrypt_with_client_key_u16(integer,
                                                        client_key,
                                                        &encrypted)
        assert(ok == 0)
        
        ok = fhe_uint16_serialize(encrypted, &buffer)
        assert(ok == 0)
        
        let data = Self.dynamicBufferToData(buffer: buffer)
        return data
    }
    
    func fheComputeOnEncryptedData(input: Data) -> Data? {
        let inputBuffer = Self.dataToDynamicBuffer(data: input)
        let bufferView = DynamicBufferView(pointer: inputBuffer.pointer, length: inputBuffer.length)
        var encryptedInput: OpaquePointer?  // FheUint16
        var encryptedOutput: OpaquePointer? // FheUint16

        // Deserialize
        var ok: Int32
        ok = fhe_uint16_deserialize(bufferView, &encryptedInput)
        assert(ok == 0)

        // Compute
        ok = fhe_uint16_scalar_add(encryptedInput, 42, &encryptedOutput)
        assert(ok == 0)
        
        // Reserialize
        var outputBuffer = DynamicBuffer(pointer: nil, length: 0, destructor: nil)
        ok = fhe_uint16_serialize(encryptedOutput, &outputBuffer)
        assert(ok == 0)
        
        let outputData = Self.dynamicBufferToData(buffer: outputBuffer)
        return outputData
    }
    
    func decryptInt(data: Data) -> Int {
        let buffer = Self.dataToDynamicBuffer(data: data)
        let bufferView = DynamicBufferView(pointer: buffer.pointer, length: buffer.length)
        var encryptedResult: OpaquePointer?
        var clearResult: UInt16 = 0

        // Step 1: Deserialize
        var ok: Int32
        ok = fhe_uint16_deserialize(bufferView, &encryptedResult)
        assert(ok == 0)
        
        // Step 2: Decrypt
        ok = fhe_uint16_decrypt(encryptedResult, client_key, &clearResult)
        assert(ok == 0)
        
        print("Decrypted result", clearResult)
        return Int(clearResult)
    }
    
    static func dataToDynamicBuffer(data: Data) -> DynamicBuffer {
        // Allocate memory for the buffer pointer and copy data into it
        let length = data.count
        let pointer = UnsafeMutablePointer<UInt8>.allocate(capacity: length)
        data.copyBytes(to: pointer, count: length)
        
        // Create the DynamicBuffer
        let buffer = DynamicBuffer(pointer: pointer, length: length, destructor: { pointer, length in
            // Free the memory when done
            pointer?.deallocate()
            return 0
        })
        
        return buffer
    }
    
    static func dynamicBufferToData(buffer: DynamicBuffer) -> Data? {
        guard let pointer = buffer.pointer else {
            return nil
        }
        
        // Create a Data object from the buffer's pointer and length
        let data = Data(bytes: pointer, count: buffer.length)
        print("Serialized data: \(data) \(data.count.formatted(.byteCount(style: .file)))")

        // Optionally, free memory using the destructor (if provided)
        if let destructor = buffer.destructor {
            let freeResult = destructor(pointer, buffer.length)
            if freeResult != 0 {
                print("Failed to free memory")
            }
        }

        return data
    }
}

//    func encryptArray(_ items: [UInt16]) {
//        print(#function)
//        let start = Date()
//        defer {
//            print(#function, "executed in \(Date().timeIntervalSince(start))s")
//        }
//
//        ensureClientServerKeysExist()
//        generatePublicKey() // TODO: Everytime or should we cache it ?
//        
//        // Create compact list
//        var ok: Int32
//        var compact_list: OpaquePointer? // CompactCiphertextList
//        var listBuilder: OpaquePointer? // CompactCiphertextListBuilder
//        
//        ok = compact_ciphertext_list_builder_new(public_key, &listBuilder);
//        assert(ok == 0);
//        
//        // Push values
//        for item in items {
//            ok = compact_ciphertext_list_builder_push_u16(listBuilder, item)
//            assert(ok == 0)
//        }
//        
//        // Build
//        ok = compact_ciphertext_list_builder_build(listBuilder, &compact_list)
//        assert(ok == 0)
//        
//        // Don't forget to destroy the builder
//        compact_ciphertext_list_builder_destroy(listBuilder);
//    }
