import Foundation
@testable import Niya

final class MockNetworkClient: Networking, @unchecked Sendable {
    var fetchCallCount = 0
    var fetchRawCallCount = 0
    var downloadCallCount = 0
    var lastFetchedURL: URL?

    var fetchResult: (any Sendable)?
    var fetchError: Error?
    var fetchRawResult: (Data, HTTPURLResponse)?
    var fetchRawError: Error?
    var downloadResult: URL?
    var downloadError: Error?

    // Track sequential results for retry testing
    var fetchResults: [(any Sendable)?] = []
    var fetchErrors: [Error?] = []
    private var fetchAttempt = 0

    func fetch<T: Decodable & Sendable>(_ type: T.Type, from url: URL) async throws -> T {
        fetchCallCount += 1
        lastFetchedURL = url

        if !fetchErrors.isEmpty || !fetchResults.isEmpty {
            let idx = fetchAttempt
            fetchAttempt += 1
            if idx < fetchErrors.count, let error = fetchErrors[idx] {
                throw error
            }
            if idx < fetchResults.count, let result = fetchResults[idx] as? T {
                return result
            }
        }

        if let error = fetchError { throw error }
        if let result = fetchResult as? T { return result }
        throw NetworkError.decodingFailed(NSError(domain: "MockNetworkClient", code: 0))
    }

    func fetchRaw(from url: URL) async throws -> (Data, HTTPURLResponse) {
        fetchRawCallCount += 1
        lastFetchedURL = url
        if let error = fetchRawError { throw error }
        if let result = fetchRawResult { return result }
        throw NetworkError.requestFailed(URLError(.badServerResponse))
    }

    func download(from url: URL) async throws -> URL {
        downloadCallCount += 1
        lastFetchedURL = url
        if let error = downloadError { throw error }
        if let result = downloadResult { return result }
        throw NetworkError.requestFailed(URLError(.badServerResponse))
    }

    func download(from url: URL, onProgress: @escaping @Sendable (Double) -> Void) async throws -> URL {
        downloadCallCount += 1
        lastFetchedURL = url
        if let error = downloadError { throw error }
        if let result = downloadResult { return result }
        throw NetworkError.requestFailed(URLError(.badServerResponse))
    }

    func reset() {
        fetchCallCount = 0
        fetchRawCallCount = 0
        downloadCallCount = 0
        lastFetchedURL = nil
        fetchResult = nil
        fetchError = nil
        fetchRawResult = nil
        fetchRawError = nil
        downloadResult = nil
        downloadError = nil
        fetchResults = []
        fetchErrors = []
        fetchAttempt = 0
    }
}
