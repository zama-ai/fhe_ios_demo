// Copyright © 2025 Zama. All rights reserved.

import Foundation

func measure<T>(_ name: String, _ block: () -> T) -> T {
    print("\(name) in progress…")
    let start = Date()
    let result = block()
    let duration = Date().timeIntervalSince(start)
    print("  ↳ \(name) done (\(duration.formatted(.number.precision(.fractionLength(3)))) seconds).")
    
    return result
}

func measure<T>(_ name: String, _ block: () throws -> T) throws -> T {
    print("\(name) in progress…")
    let start = Date()
    do {
        let result = try block()
        let duration = Date().timeIntervalSince(start)
        print("  ↳ \(name) done (\(duration.formatted(.number.precision(.fractionLength(3)))) seconds).")
        return result
    } catch {
        let duration = Date().timeIntervalSince(start)
        print("  ↳ \(name) exception (\(duration.formatted(.number.precision(.fractionLength(3)))) seconds)")
        throw error
    }
}

func measureAsync<T>(_ name: String, _ operation: @escaping () async throws -> T) async rethrows -> T {
    print("\(name) in progress…")
    let clock = ContinuousClock()
    let start = clock.now
    let result = try await operation()
    let duration = start.duration(to: clock.now).components.seconds
    print("  ↳ \(name) done (\(duration.formatted(.number.precision(.fractionLength(3)))) seconds).")
    return result
}
