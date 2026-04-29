import Foundation

struct AnalysisService {
    let apiKey: String
    let model: String

    private static let systemPrompt = """
        请用中文分析这个 AI skill 文件，严格按以下 Markdown 格式输出，不要增减章节：

        **用途**
        一句话描述核心功能。

        **触发时机**
        - 触发场景一
        - 触发场景二（按实际列举）

        **主要步骤**
        1. 第一步
        2. 第二步（按实际列举）

        要求：文件路径和命令用 `反引号` 标注；总字数不超过 300 字；只输出上述格式内容，不要额外说明。
        """

    func analyze(content: String) async throws -> String {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": Self.systemPrompt],
                ["role": "user",   "content": content]
            ],
            "max_tokens": 1000
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw AnalysisError.invalidResponse
        }
        guard http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw AnalysisError.apiError(http.statusCode, body)
        }

        guard
            let json    = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let message = choices.first?["message"] as? [String: Any],
            let text    = message["content"] as? String
        else {
            throw AnalysisError.parseError
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    enum AnalysisError: LocalizedError {
        case invalidResponse
        case apiError(Int, String)
        case parseError

        var errorDescription: String? {
            switch self {
            case .invalidResponse:            return "无效的服务器响应"
            case .apiError(let code, let b):  return "API 错误 \(code)：\(b)"
            case .parseError:                 return "解析响应失败"
            }
        }
    }
}
