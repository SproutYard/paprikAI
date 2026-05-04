import Foundation
import Observation
import SwiftUI

@Observable
class RecipeStore {
    private(set) var recipes: [ExtractedRecipe] = []

    private let storageKey = "paprikAI_saved_recipes"

    init() {
        load()
    }

    func add(_ recipe: ExtractedRecipe) {
        recipes.insert(recipe, at: 0)
        save()
    }

    func update(_ recipe: ExtractedRecipe) {
        guard let index = recipes.firstIndex(where: { $0.id == recipe.id }) else { return }
        recipes[index] = recipe
        save()
    }

    func remove(at offsets: IndexSet) {
        recipes.remove(atOffsets: offsets)
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let saved = try? JSONDecoder().decode([ExtractedRecipe].self, from: data) else { return }
        recipes = saved
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(recipes) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
