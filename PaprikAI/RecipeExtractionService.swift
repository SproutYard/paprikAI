import UIKit
import Foundation

struct RecipeExtractionService {

    private let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!

    func extract(from images: [UIImage]) async throws -> ExtractedRecipe {
        let key = APIConfig.openAIKey
        guard !key.isEmpty else { throw ExtractionError.missingAPIKey }

        var contentParts: [[String: Any]] = [["type": "text", "text": userPrompt]]

        for image in images {
            guard let jpegData = image.jpegData(compressionQuality: 0.85) else { continue }
            let b64 = jpegData.base64EncodedString()
            contentParts.append([
                "type": "image_url",
                "image_url": ["url": "data:image/jpeg;base64,\(b64)", "detail": "high"]
            ])
        }

        let body: [String: Any] = [
            "model": APIConfig.openAIModel,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": contentParts]
            ],
            "response_format": ["type": "json_object"],
            "temperature": 0,
            "max_tokens": 4096
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else { throw ExtractionError.networkError }
        guard http.statusCode == 200 else {
            let msg = String(data: data, encoding: .utf8) ?? "(no body)"
            throw ExtractionError.apiError(http.statusCode, msg)
        }

        return try parseResponse(data)
    }

    private func parseResponse(_ data: Data) throws -> ExtractedRecipe {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = root["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String,
              let contentData = content.data(using: .utf8) else {
            throw ExtractionError.invalidResponse
        }

        guard let r = try JSONSerialization.jsonObject(with: contentData) as? [String: Any] else {
            throw ExtractionError.invalidResponse
        }

        func str(_ k: String) -> String { r[k] as? String ?? "" }
        func arr(_ k: String) -> [String] { r[k] as? [String] ?? [] }

        let ingredients: [String]
        if let a = r["ingredients"] as? [String] { ingredients = a }
        else if let s = r["ingredients"] as? String {
            ingredients = s.components(separatedBy: "\n").filter { !$0.isEmpty }
        } else { ingredients = [] }

        let directions: [String]
        if let a = r["directions"] as? [String] { directions = a }
        else if let s = r["directions"] as? String {
            directions = s.components(separatedBy: "\n\n").filter { !$0.isEmpty }
        } else { directions = [] }

        return ExtractedRecipe(
            name: str("name"),
            description: str("description"),
            ingredients: ingredients,
            directions: directions,
            prepTime: str("prep_time"),
            cookTime: str("cook_time"),
            totalTime: str("total_time"),
            servings: str("servings"),
            categories: arr("categories"),
            notes: str("notes"),
            source: str("source"),
            sourceURL: str("source_url"),
            nutritionalInfo: str("nutritional_info")
        )
    }

    private var systemPrompt: String {
        "You are a professional recipe transcription assistant. Your highest priority is accuracy: every quantity and ingredient must match the source image exactly. Do not invent, round, or reinterpret any information."
    }

    private var userPrompt: String {
        """
        Extract the recipe from the provided image(s) and return a JSON object with exactly these fields:

        {
          "name": "Recipe name",
          "description": "Brief description if present, otherwise empty string",
          "ingredients": ["ingredient line 1", "ingredient line 2"],
          "directions": ["Step 1 text", "Step 2 text"],
          "prep_time": "e.g. 20 min",
          "cook_time": "e.g. 30 min",
          "total_time": "e.g. 50 min",
          "servings": "e.g. 4 servings",
          "categories": ["category1"],
          "notes": "Tips or notes from the recipe",
          "source": "Publication or website name if visible",
          "source_url": "URL if visible",
          "nutritional_info": "Nutritional info if present"
        }

        Rules:
        - Preserve the original recipe faithfully. Do not invent missing quantities or steps.
        - Copy ingredient quantities character-for-character from the image. Do not round, simplify, or reinterpret fractions — for example, "1/2" must remain "1/2", never "2" or "0.5". After extracting all ingredients, verify each quantity against the image before returning. If a quantity is unclear, transcribe your best read and append "(unclear)" rather than guessing a different value.
        - If multiple images are provided, merge all information into one recipe.
        - Return ingredients as an ordered array, one ingredient per element. Preserve order.
        - If the recipe has named ingredient sections (e.g. "Salad", "Dressing", "Sauce", "For the crust"), include the section header as an element prefixed with "!" — for example "!Salad" — immediately before that section's ingredients. Only add section headers when they are explicitly present in the recipe; do not invent them.
        - Return directions as an ordered array, one step per element, without step numbers.
        - Use empty string or empty array for missing fields.
        - If uncertain, note it in the "notes" field.
        - If a book cover or book title is visible, add it to the "notes" field as "From: [Book Title]". If a page number is also visible, append it: "From: [Book Title], page [N]". If only a page number is visible with no book title, add "page [N]" to the notes.
        - Ignore ads and unrelated text.
        """
    }

    enum ExtractionError: LocalizedError {
        case missingAPIKey
        case networkError
        case apiError(Int, String)
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "OpenAI API key not configured. Set OPENAI_API_KEY in your scheme's environment variables."
            case .networkError:
                return "Network error during recipe extraction."
            case .apiError(let code, let body):
                return "API error \(code): \(body)"
            case .invalidResponse:
                return "Could not parse the recipe from the API response."
            }
        }
    }
}
