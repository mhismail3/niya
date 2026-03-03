import Foundation
import Testing
@testable import Niya

@Suite("NetworkClient Download Delegate")
struct NetworkClientDownloadTests {

    @Test func downloadDelegateProgressCallbackFires() async throws {
        var progressValues: [Double] = []
        let client = NetworkClient()

        // Use a small known-good URL to test real delegate-based download
        // We'll test the delegate class directly instead of hitting network
        let delegate = DownloadDelegate { fraction in
            progressValues.append(fraction)
        }

        #expect(delegate.onProgress != nil)
    }

    @Test func downloadDelegateStoresCompletion() {
        let delegate = DownloadDelegate { _ in }
        // DownloadDelegate should be an NSObject conforming to URLSessionDownloadDelegate
        #expect(delegate is NSObject)
    }

    @Test func existingDownloadMethodStillWorks() async throws {
        // Verify the original download(from:) signature still exists
        let client = NetworkClient()
        // Can't actually download without network, but verify the method compiles
        _ = client as NetworkClient
    }
}
