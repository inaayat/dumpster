import Foundation

protocol AIBackend: Sendable {
    func send(system: String, userMessage: String, maxTokens: Int) async throws -> String
    func checkAvailability() async throws
}

struct OllamaBackend: AIBackend {
    private let url = URL(string: "http://localhost:11434/api/chat")!
    private let model = "gemma2:9b"

    func checkAvailability() async throws {
        guard let tagURL = URL(string: "http://localhost:11434/api/tags") else {
            throw AIError.unavailable
        }
        guard let (data, response) = try? await URLSession.shared.data(from: tagURL),
              let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AIError.unavailable
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let models = json["models"] as? [[String: Any]],
              models.contains(where: { ($0["name"] as? String) == model }) else {
            throw AIError.modelNotPulled(model)
        }
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
    case modelNotPulled(String)
    case apiError(statusCode: Int, message: String)
    case emptyResponse
    case parseError

    var errorDescription: String? {
        switch self {
        case .unavailable: return "Ollama isn't running. Start it with: ollama serve"
        case .modelNotPulled(let name): return "Model not found. Run: ollama pull \(name)"
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
        do { try await backend.checkAvailability(); return true }
        catch { return false }
    }

    func send(system: String, userMessage: String, maxTokens: Int = 1024) async throws -> String {
        try await backend.checkAvailability()
        return try await backend.send(system: system, userMessage: userMessage, maxTokens: maxTokens)
    }
}
