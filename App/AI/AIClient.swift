import Foundation

/// Optional AI helper. Off until the user configures a provider.
/// Privacy: only the text you type (and, for "explain failure", that one command + exit code + cwd) is sent.
enum AIClient {
    enum AIError: LocalizedError {
        case notConfigured, http(Int, String), badResponse
        var errorDescription: String? {
            switch self {
            case .notConfigured: "AI not configured. Add an API key in Settings → AI, or choose Ollama."
            case .http(let c, let m): "AI request failed (\(c)): \(m)"
            case .badResponse: "Unexpected AI response."
            }
        }
    }

    static let keychainAccount = "anthropic-api-key"

    static func defaultModel(for provider: String) -> String {
        provider == "ollama" ? "llama3.2" : "claude-sonnet-5-5"
    }

    static let commandSystem = """
    You convert a request into ONE macOS zsh/bash shell command. \
    Reply with only the command, no explanation, no markdown fences.
    """
    static let explainSystem = """
    You are a concise terminal assistant on macOS. Explain why the command failed and give the fixed command on the last line. \
    Keep it under 120 words.
    """

    static func complete(system: String, user: String, provider: String, model: String) async throws -> String {
        let model = model.isEmpty ? defaultModel(for: provider) : model
        if provider == "ollama" {
            var req = URLRequest(url: URL(string: "http://localhost:11434/api/chat")!)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "content-type")
            req.httpBody = try JSONSerialization.data(withJSONObject: [
                "model": model, "stream": false,
                "messages": [["role": "system", "content": system], ["role": "user", "content": user]]])
            let (data, resp) = try await URLSession.shared.data(for: req)
            try check(resp, data)
            guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let msg = obj["message"] as? [String: Any], let text = msg["content"] as? String
            else { throw AIError.badResponse }
            return clean(text)
        }
        guard let key = Keychain.get(account: keychainAccount), !key.isEmpty else { throw AIError.notConfigured }
        var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        req.httpMethod = "POST"
        req.setValue(key, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": model, "max_tokens": 400, "system": system,
            "messages": [["role": "user", "content": user]]])
        let (data, resp) = try await URLSession.shared.data(for: req)
        try check(resp, data)
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = obj["content"] as? [[String: Any]],
              let text = content.first?["text"] as? String else { throw AIError.badResponse }
        return clean(text)
    }

    private static func check(_ resp: URLResponse, _ data: Data) throws {
        guard let h = resp as? HTTPURLResponse else { throw AIError.badResponse }
        guard (200..<300).contains(h.statusCode) else {
            throw AIError.http(h.statusCode, String(decoding: data.prefix(200), as: UTF8.self))
        }
    }

    /// Strips markdown fences if the model added them.
    static func clean(_ s: String) -> String {
        var t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasPrefix("```") {
            t = t.split(separator: "\n", omittingEmptySubsequences: false).dropFirst().joined(separator: "\n")
            if let r = t.range(of: "```", options: .backwards) { t = String(t[..<r.lowerBound]) }
        }
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
