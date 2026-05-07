import SwiftUI

struct RecipeDetailView: View {
    let recipe: ExtractedRecipe

    @State private var exportError: String? = nil
    @Environment(RecipeStore.self) private var store

    var body: some View {
        RecipeReadOnlyView(
            recipe: recipe,
            onYAML: {
                handleExport { try PaprikaExportService().exportYAML(recipe: recipe) }
            },
            onPaprika: {
                handleExport { try PaprikaExportService().exportPaprika(recipe: recipe, photo: nil) }
            }
        )
        .navigationTitle(recipe.name.isEmpty ? "Recipe" : recipe.name)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Export Error", isPresented: Binding(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        )) {
            Button("OK") { exportError = nil }
        } message: {
            Text(exportError ?? "")
        }
    }

    private func handleExport(_ makeURL: () throws -> URL) {
        do { presentShareSheet(items: [try makeURL()]) }
        catch { exportError = error.localizedDescription }
    }
}
