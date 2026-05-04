import Foundation

// TODO: Replace with a secure backend proxy before shipping to production.
//
// For development: copy .env.example to .env in the project root and fill in your key.
//   OPENAI_API_KEY=sk-...
// The app reads it automatically in DEBUG builds (Simulator). No Xcode scheme changes needed.
enum APIConfig {
    static var openAIKey: String {
        if let key = keyFromDotEnv, !key.isEmpty { return key }
        if let key = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !key.isEmpty { return key }
        if let key = Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String, !key.isEmpty { return key }
        return ""
    }

    static var openAIModel: String { "gpt-4o" }

    // Reads .env from the project root at compile-time source path.
    // Only runs in DEBUG — has no effect in Release builds.
    private static var keyFromDotEnv: String? {
        #if DEBUG
        let envURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // PaprikAI/
            .deletingLastPathComponent()  // project root
            .appendingPathComponent(".env")
        guard let contents = try? String(contentsOf: envURL, encoding: .utf8) else { return nil }
        for line in contents.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.hasPrefix("#"), let eqRange = trimmed.range(of: "=") else { continue }
            let key = String(trimmed[trimmed.startIndex ..< eqRange.lowerBound])
            let value = String(trimmed[eqRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            if key == "OPENAI_API_KEY" { return value }
        }
        return nil
        #else
        return nil
        #endif
    }
}
