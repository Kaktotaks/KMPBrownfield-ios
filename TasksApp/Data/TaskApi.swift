import Foundation

/// Network access for tasks. Protocol so it can be faked in tests/previews.
/// Stays Swift in this migration step (later: Ktor client in the shared module).
protocol TaskApi {
    func fetchTodos() async throws -> [TodoDto]
}

enum TaskApiError: Error {
    case badStatus(Int)
}

struct URLSessionTaskApi: TaskApi {
    static let todosURL = URL(string: "https://jsonplaceholder.typicode.com/todos?_limit=20")!

    private let session: URLSession
    private let url: URL

    init(session: URLSession = .shared, url: URL = URLSessionTaskApi.todosURL) {
        self.session = session
        self.url = url
    }

    func fetchTodos() async throws -> [TodoDto] {
        let (data, response) = try await session.data(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw TaskApiError.badStatus(http.statusCode)
        }
        return try JSONDecoder().decode([TodoDto].self, from: data)
    }
}
