import SwiftUI

struct RecipeReviewView: View {
    @Bindable var vm: NewRecipeViewModel
    var onExport: (URL) -> Void

    @State private var exportError: String? = nil

    var body: some View {
        RecipeReadOnlyView(
            recipe: vm.recipe,
            onYAML: { handleExport { try vm.createYAMLExportFile() } },
            onPaprika: { handleExport { try vm.createPaprikaExportFile() } }
        )
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
        do { onExport(try makeURL()) }
        catch { exportError = error.localizedDescription }
    }
}
