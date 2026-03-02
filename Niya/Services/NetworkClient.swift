import Foundation

enum NetworkError: LocalizedError {
    case badStatus(Int)
    case decodingFailed(Error)
    case requestFailed(Error)

    var errorDescription: String? {
        switch self {
        case .badStatus(let code): return "HTTP \(code)"
        case .decodingFailed(let error): return "Decoding failed: \(error.localizedDescription)"
        case .requestFailed(let error): return error.localizedDescription
        }
    }
}

struct NetworkClient: Sendable {
    static let shared = NetworkClient()

    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        session = URLSession(configuration: config)
    }

    func fetch<T: Decodable>(_ type: T.Type, from url: URL) async throws -> T {
        let (data, _) = try await fetchRaw(from: url)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw NetworkError.decodingFailed(error)
        }
    }

    func fetchRaw(from url: URL) async throws -> (Data, HTTPURLResponse) {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(from: url)
        } catch {
            throw NetworkError.requestFailed(error)
        }
        guard let http = response as? HTTPURLResponse else {
            throw NetworkError.requestFailed(URLError(.badServerResponse))
        }
        guard (200...299).contains(http.statusCode) else {
            throw NetworkError.badStatus(http.statusCode)
        }
        return (data, http)
    }

    func download(from url: URL) async throws -> URL {
        let (tempURL, response): (URL, URLResponse)
        do {
            (tempURL, response) = try await session.download(from: url)
        } catch {
            throw NetworkError.requestFailed(error)
        }
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            throw NetworkError.badStatus((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        return tempURL
    }
}
