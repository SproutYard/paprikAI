import Foundation

struct ExtractedRecipe: Codable, Identifiable {
    var id: UUID
    var name: String
    var description: String
    var ingredients: [String]
    var directions: [String]
    var prepTime: String
    var cookTime: String
    var totalTime: String
    var servings: String
    var categories: [String]
    var notes: String
    var source: String
    var sourceURL: String
    var nutritionalInfo: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String = "",
        description: String = "",
        ingredients: [String] = [],
        directions: [String] = [],
        prepTime: String = "",
        cookTime: String = "",
        totalTime: String = "",
        servings: String = "",
        categories: [String] = [],
        notes: String = "",
        source: String = "PaprikAI",
        sourceURL: String = "",
        nutritionalInfo: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.ingredients = ingredients
        self.directions = directions
        self.prepTime = prepTime
        self.cookTime = cookTime
        self.totalTime = totalTime
        self.servings = servings
        self.categories = categories
        self.notes = notes
        self.source = source
        self.sourceURL = sourceURL
        self.nutritionalInfo = nutritionalInfo
        self.createdAt = createdAt
    }
}
