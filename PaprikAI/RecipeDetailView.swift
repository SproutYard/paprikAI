import SwiftUI

struct RecipeDetailView: View {
    let recipe: ExtractedRecipe

    @State private var local: ExtractedRecipe
    @State private var exportError: String? = nil
    @Environment(RecipeStore.self) private var store

    init(recipe: ExtractedRecipe) {
        self.recipe = recipe
        _local = State(initialValue: recipe)
    }

    var body: some View {
        Form {
            Section("Name") {
                TextField("Recipe Name", text: $local.name)
            }

            Section("Times & Servings") {
                LabeledContent("Prep") {
                    TextField("e.g. 20 min", text: $local.prepTime)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Cook") {
                    TextField("e.g. 30 min", text: $local.cookTime)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Total") {
                    TextField("e.g. 50 min", text: $local.totalTime)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Servings") {
                    TextField("e.g. 4 servings", text: $local.servings)
                        .multilineTextAlignment(.trailing)
                }
            }

            Section("Categories") {
                TextField("e.g. Desserts, Cookies", text: categoriesBinding)
                    .autocorrectionDisabled()
            }

            Section("Ingredients") {
                TextEditor(text: ingredientsBinding)
                    .frame(minHeight: 120)
                    .font(.body)
            }

            Section("Directions") {
                TextEditor(text: directionsBinding)
                    .frame(minHeight: 160)
                    .font(.body)
            }

            Section("Description") {
                TextEditor(text: $local.description)
                    .frame(minHeight: 60)
                    .font(.body)
            }

            Section("Notes") {
                TextEditor(text: $local.notes)
                    .frame(minHeight: 60)
                    .font(.body)
            }

            Section("Nutritional Info") {
                TextEditor(text: $local.nutritionalInfo)
                    .frame(minHeight: 60)
                    .font(.body)
            }

            Section("Source") {
                TextField("Source name", text: $local.source)
                TextField("URL", text: $local.sourceURL)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }

            Section {
                Button {
                    handleExport()
                } label: {
                    Label("Re-export to Paprika", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                        .bold()
                }
                .buttonStyle(.borderedProminent)
                .disabled(local.name.isEmpty)
            }
        }
        .navigationTitle(local.name.isEmpty ? "Recipe" : local.name)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Export Error", isPresented: .init(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        )) {
            Button("OK") { exportError = nil }
        } message: {
            Text(exportError ?? "")
        }
    }

    private func handleExport() {
        do {
            let url = try PaprikaExportService().export(recipe: local, photo: nil)
            store.update(local)
            presentShareSheet(items: [url])
        } catch {
            exportError = error.localizedDescription
        }
    }

    private var ingredientsBinding: Binding<String> {
        Binding(
            get: { local.ingredients.joined(separator: "\n") },
            set: { local.ingredients = $0.components(separatedBy: "\n").filter { !$0.isEmpty } }
        )
    }

    private var directionsBinding: Binding<String> {
        Binding(
            get: { local.directions.joined(separator: "\n\n") },
            set: { local.directions = $0.components(separatedBy: "\n\n").filter { !$0.isEmpty } }
        )
    }

    private var categoriesBinding: Binding<String> {
        Binding(
            get: { local.categories.joined(separator: ", ") },
            set: {
                local.categories = $0
                    .components(separatedBy: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
            }
        )
    }
}
