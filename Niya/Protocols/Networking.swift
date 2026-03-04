import Foundation

protocol Networking: Sendable {
    func fetch<T: Decodable & Sendable>(_ type: T.Type, from url: URL) async throws -> T
    func fetchRaw(from url: URL) async throws -> (Data, HTTPURLResponse)
    func download(from url: URL) async throws -> URL
    func download(from url: URL, onProgress: @escaping @Sendable (Double) -> Void) async throws -> URL
}
