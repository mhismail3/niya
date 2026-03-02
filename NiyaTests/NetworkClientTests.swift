import Foundation
import Testing
@testable import Niya

@Suite("NetworkClient")
struct NetworkClientTests {

    @Test func badStatusError_description() {
        let error = NetworkError.badStatus(404)
        #expect(error.errorDescription == "HTTP 404")
    }

    @Test func requestFailedError_description() {
        let underlying = URLError(.timedOut)
        let error = NetworkError.requestFailed(underlying)
        #expect(error.errorDescription != nil)
    }

    @Test func decodingFailedError_description() {
        let underlying = DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "test"))
        let error = NetworkError.decodingFailed(underlying)
        #expect(error.errorDescription?.contains("Decoding failed") == true)
    }

    @Test func sharedInstance_exists() {
        let client = NetworkClient.shared
        _ = client
    }
}
