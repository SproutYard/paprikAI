import UIKit
import Foundation

struct RecipeExtractionService {

    private let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!

    func extract(from images: [UIImage]) async throws -> ExtractedRecipe {
        let key = APIConfig.openAIKey
        guard !key.isEmpty else { throw ExtractionError.missingAPIKey }

        var recipe = try await runExtraction(images: images, key: key)

        if let idx = recipe.ingredientsPhotoIndex, idx < images.count {
            let verified = try await verifyIngredients(
                recipe.ingredients,
                in: images[idx],
                key: key
            )
            recipe.ingredients = verified
        }

        recipe.ingredientsPhotoIndex = nil
        return recipe
    }

    private func runExtraction(images: [UIImage], key: String) async throws -> ExtractedRecipe {
        var contentParts: [[String: Any]] = [["type": "text", "text": userPrompt]]

        for image in images {
            guard let jpegData = image.jpegData(compressionQuality: 0.85) else { continue }
            let b64 = jpegData.base64EncodedString()
            contentParts.append([
                "type": "image_url",
                "image_url": ["url": "data:image/jpeg;base64,\(b64)", "detail": "high"]
            ])
        }

        let data = try await post(contentParts: contentParts, key: key)
        return try parseResponse(data)
    }

    private func verifyIngredients(_ ingredients: [String], in image: UIImage, key: String) async throws -> [String] {
        guard let jpegData = image.jpegData(compressionQuality: 0.85) else { return ingredients }
        let b64 = jpegData.base64EncodedString()

        let extracted = ingredients.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
        let prompt = """
        You are verifying a recipe ingredient list against a source image. Re-read every ingredient from the image character-for-character and compare it to the list below.

        Extracted list:
        \(extracted)

        Return a JSON object with a single key "ingredients" containing the corrected array. Preserve the original order. Copy quantities exactly as they appear in the image — do not round, simplify, or reinterpret fractions. If an ingredient from the list is not visible in the image, keep it unchanged. If a quantity is unclear, append "(unclear)".
        """

        let contentParts: [[String: Any]] = [
            ["type": "text", "text": prompt],
            ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(b64)", "detail": "high"]]
        ]

        let data = try await post(contentParts: contentParts, key: key)

        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = root["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String,
              let contentData = content.data(using: .utf8),
              let r = try JSONSerialization.jsonObject(with: contentData) as? [String: Any],
              let verified = r["ingredients"] as? [String] else {
            return ingredients
        }

        return verified
    }

    private func post(contentParts: [[String: Any]], key: String) async throws -> Data {
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

        return data
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

        let bestPhotoIndex = r["best_photo_index"] as? Int ?? 0
        let ingredientsPhotoIndex = r["ingredients_photo_index"] as? Int

        return ExtractedRecipe(
            name: str("name"),
            description: str("description"),
            ingredients: ingredients,
            directions: directions,
            prepTime: str("prep_time"),
            cookTime: str("cook_time"),
            totalTime: str("total_time"),
            servings: str("servings"),
            categories: [],
            notes: str("notes"),
            source: str("source"),
            sourceURL: str("source_url"),
            nutritionalInfo: str("nutritional_info"),
            selectedPhotoIndex: bestPhotoIndex,
            ingredientsPhotoIndex: ingredientsPhotoIndex
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
          "notes": "Tips or notes from the recipe",
          "source": "Publication or website name if visible",
          "source_url": "URL if visible",
          "nutritional_info": "Nutritional info if present",
          "best_photo_index": 0,
          "ingredients_photo_index": 0
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
        - If multiple images are provided, set "best_photo_index" to the 0-based index of the image that would make the best recipe hero photo (prefer a plated or finished dish over text, recipe cards, or ingredient shots). If only one image is provided or no image shows food, use 0.
        - Set "ingredients_photo_index" to the 0-based index of the image that contains the complete ingredients list. If only one image is provided, use 0. If no single image clearly contains the ingredients list, omit this field.
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
