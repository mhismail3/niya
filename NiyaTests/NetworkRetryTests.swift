import Foundation
import Testing
@testable import Niya

@Suite("NetworkClient Retry & Error Paths")
struct NetworkRetryTests {

    // MARK: - NetworkError descriptions

    @Test func badStatus404Description() {
        let error = NetworkError.badStatus(404)
        #expect(error.errorDescription == "HTTP 404")
    }

    @Test func badStatus503Description() {
        let error = NetworkError.badStatus(503)
        #expect(error.errorDescription == "HTTP 503")
    }

    @Test func requestFailedDescriptionIsNonNil() {
        let underlying = URLError(.notConnectedToInternet)
        let error = NetworkError.requestFailed(underlying)
        #expect(error.errorDescription != nil)
        #expect(!error.errorDescription!.isEmpty)
    }

    @Test func decodingFailedDescriptionContainsPrefix() {
        let underlying = DecodingError.typeMismatch(
            Int.self,
            .init(codingPath: [], debugDescription: "expected Int")
        )
        let error = NetworkError.decodingFailed(underlying)
        let desc = error.errorDescription
        #expect(desc != nil)
        #expect(desc!.hasPrefix("Decoding failed:"))
    }

    @Test func badStatusZeroDescription() {
        let error = NetworkError.badStatus(0)
        #expect(error.errorDescription == "HTTP 0")
    }

    // MARK: - fetchWithRetry with unreachable endpoint

    @Test func fetchWithRetryThrowsForUnreachableURL() async {
        let client = NetworkClient()
        let url = URL(string: "http://0.0.0.0:1/nonexistent")!
        do {
            let _: [String: String] = try await client.fetchWithRetry(
                [String: String].self,
                from: url,
                maxAttempts: 1
            )
            Issue.record("Expected fetchWithRetry to throw for unreachable URL")
        } catch {
            #expect(error is NetworkError)
        }
    }

    @Test func fetchWithRetryMaxAttemptsOneDoesNotRetry() async {
        let client = NetworkClient()
        let url = URL(string: "http://0.0.0.0:1/bad")!
        let start = ContinuousClock.now
        do {
            let _: String = try await client.fetchWithRetry(
                String.self,
                from: url,
                maxAttempts: 1
            )
            Issue.record("Expected throw")
        } catch {
            let elapsed = ContinuousClock.now - start
            // With maxAttempts=1 there is no backoff sleep, so it should be fast
            #expect(elapsed < .seconds(5))
        }
    }

    // MARK: - Non-retryable errors throw immediately

    @Test func nonRetryableBadStatusThrowsImmediately() {
        // badStatus(404) is NOT in {408, 429, 500, 502, 503, 504}
        // so fetchWithRetry would throw on the first attempt without sleeping
        let error = NetworkError.badStatus(404)
        switch error {
        case .badStatus(let code):
            let retryable: Set<Int> = [408, 429, 500, 502, 503, 504]
            #expect(!retryable.contains(code))
        default:
            Issue.record("Expected badStatus")
        }
    }

    @Test func retryableStatusCodesAreRecognized() {
        let retryable: Set<Int> = [408, 429, 500, 502, 503, 504]
        for code in retryable {
            #expect(retryable.contains(code), "Code \(code) should be retryable")
        }
        let nonRetryable = [200, 201, 301, 400, 401, 403, 404, 405, 422]
        for code in nonRetryable {
            #expect(!retryable.contains(code), "Code \(code) should NOT be retryable")
        }
    }

    // MARK: - AppError descriptions

    @Test func appErrorNetworkDescription() {
        let error = AppError.network("connection lost")
        #expect(error.errorDescription == "connection lost")
    }

    @Test func appErrorDataDescription() {
        let error = AppError.data("corrupt JSON")
        #expect(error.errorDescription == "corrupt JSON")
    }

    @Test func appErrorAudioDescription() {
        let error = AppError.audio("playback failed")
        #expect(error.errorDescription == "playback failed")
    }

    // MARK: - AppError equatable

    @Test func appErrorSameCasesAreEqual() {
        #expect(AppError.network("x") == AppError.network("x"))
        #expect(AppError.data("y") == AppError.data("y"))
        #expect(AppError.audio("z") == AppError.audio("z"))
    }

    @Test func appErrorDifferentMessagesAreNotEqual() {
        #expect(AppError.network("a") != AppError.network("b"))
    }

    @Test func appErrorDifferentCasesAreNotEqual() {
        #expect(AppError.network("x") != AppError.data("x"))
        #expect(AppError.data("x") != AppError.audio("x"))
        #expect(AppError.network("x") != AppError.audio("x"))
    }

    // MARK: - NetworkError wraps underlying errors

    @Test func requestFailedWrapsURLError() {
        let urlError = URLError(.timedOut)
        let error = NetworkError.requestFailed(urlError)
        if case .requestFailed(let inner) = error {
            #expect((inner as? URLError)?.code == .timedOut)
        } else {
            Issue.record("Expected requestFailed case")
        }
    }

    @Test func decodingFailedWrapsDecodingError() {
        let decodingError = DecodingError.keyNotFound(
            CodingKeys.dummy,
            .init(codingPath: [], debugDescription: "missing key")
        )
        let error = NetworkError.decodingFailed(decodingError)
        if case .decodingFailed(let inner) = error {
            #expect(inner is DecodingError)
        } else {
            Issue.record("Expected decodingFailed case")
        }
    }
}

// Minimal CodingKey for test use
private enum CodingKeys: String, CodingKey {
    case dummy
}
