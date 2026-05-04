import Foundation

struct PaprikaExportService {

    func export(recipe: ExtractedRecipe) throws -> URL {
        let yaml = buildYAML(from: recipe)
        guard let data = yaml.data(using: .utf8) else {
            throw ExportError.encodingFailed
        }

        let safeName = sanitized(recipe.name.isEmpty ? "Recipe" : recipe.name)
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(safeName).paprikarecipes")

        try data.write(to: outputURL, options: .atomic)
        return outputURL
    }

    private func buildYAML(from recipe: ExtractedRecipe) -> String {
        var lines: [String] = []

        // Scalar value — quoted to handle colons, special chars, etc.
        func scalar(_ key: String, _ value: String) {
            guard !value.isEmpty else { return }
            let escaped = value
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
            lines.append("\(key): \"\(escaped)\"")
        }

        // Block scalar — preserves newlines and blank lines
        func block(_ key: String, _ value: String) {
            guard !value.isEmpty else { return }
            lines.append("\(key): |")
            for line in value.components(separatedBy: "\n") {
                lines.append(line.isEmpty ? "" : "  \(line)")
            }
        }

        scalar("name", recipe.name)
        scalar("servings", recipe.servings)
        scalar("prep_time", recipe.prepTime)
        scalar("cook_time", recipe.cookTime)
        scalar("total_time", recipe.totalTime)
        scalar("source", recipe.source)
        scalar("source_url", recipe.sourceURL)
        if !recipe.categories.isEmpty {
            scalar("categories", recipe.categories.joined(separator: ", "))
        }
        block("description", recipe.description)
        block("nutritional_info", recipe.nutritionalInfo)
        block("notes", recipe.notes)
        block("ingredients", recipe.ingredients.joined(separator: "\n"))
        block("directions", recipe.directions.joined(separator: "\n\n"))

        return lines.joined(separator: "\n") + "\n"
    }

    private func sanitized(_ name: String) -> String {
        let forbidden = CharacterSet(charactersIn: "/\\:*?\"<>|")
        return name.components(separatedBy: forbidden).joined(separator: "_")
    }

    enum ExportError: LocalizedError {
        case encodingFailed
        var errorDescription: String? { "Failed to encode recipe as UTF-8." }
    }
}
