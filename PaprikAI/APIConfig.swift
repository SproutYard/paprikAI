import Foundation

// TODO: Replace with a secure backend proxy before shipping to production.
//
// To set the key for development in Simulator:
//   Product → Scheme → Edit Scheme → Run → Environment Variables
//   Add OPENAI_API_KEY = sk-...
//
// To load from an xcconfig:
//   1. Create Config.xcconfig (add to .gitignore) with: OPENAI_API_KEY = sk-...
//   2. Add INFOPLIST_KEY_OPENAI_API_KEY = $(OPENAI_API_KEY) to xcconfig
//   3. Assign the xcconfig to the Debug and Release configurations in Xcode
enum APIConfig {
    static var openAIKey: String {
        if let key = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !key.isEmpty {
            return key
        }
        if let key = Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String, !key.isEmpty {
            return key
        }
        return ""
    }

    static var openAIModel: String { "gpt-4o" }
}
