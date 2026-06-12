import Foundation

protocol AIBackend: Sendable {
    func send(system: String, userMessage: String, maxTokens: Int) async throws -> String
    func isAvailable() async -> Bool
}

struct OllamaBackend: AIBackend {
    private let url = URL(string: "http://localhost:11434/api/chat")!
    private let model = "llama3.2"

    func isAvailable() async -> Bool {
        guard let tagURL = URL(string: "http://localhost:11434/api/tags") else { return false }
        guard let (_, response) = try? await URLSession.shared.data(from: tagURL),
              let http = response as? HTTPURLResponse, http.statusCode == 200 else { return false }
        return true
    }

    func send(system: String, userMessage: String, maxTokens: Int) async throws -> String {
        let body: [String: Any] = [
            "model": model,
            "stream": false,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": userMessage]
            ]
        ]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 120

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AIError.apiError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0, message: "Ollama error")
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let message = json["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIError.emptyResponse
        }
        return content
    }
}

enum AIError: Error, LocalizedError {
    case unavailable
    case apiError(statusCode: Int, message: String)
    case emptyResponse
    case parseError

    var errorDescription: String? {
        switch self {
        case .unavailable: return "AI not available. Start Ollama with: ollama serve"
        case .apiError(let code, let msg): return "API error (\(code)): \(msg)"
        case .emptyResponse: return "Empty response from AI"
        case .parseError: return "Failed to parse AI response"
        }
    }
}

struct AIClient: Sendable {
    static let shared = AIClient()

    private let backend: AIBackend = OllamaBackend()

    func isAvailable() async -> Bool {
        await backend.isAvailable()
    }

    func send(system: String, userMessage: String, maxTokens: Int = 1024) async throws -> String {
        guard await backend.isAvailable() else { throw AIError.unavailable }
        return try await backend.send(system: system, userMessage: userMessage, maxTokens: maxTokens)
    }
}
