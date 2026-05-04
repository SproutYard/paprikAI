import SwiftUI

struct RecipeReviewView: View {
    @Bindable var vm: NewRecipeViewModel
    var onExport: (URL) -> Void

    @State private var exportError: String? = nil

    var body: some View {
        Form {
            Section("Name") {
                TextField("Recipe Name", text: $vm.recipe.name)
            }

            Section("Times & Servings") {
                LabeledContent("Prep") {
                    TextField("e.g. 20 min", text: $vm.recipe.prepTime)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Cook") {
                    TextField("e.g. 30 min", text: $vm.recipe.cookTime)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Total") {
                    TextField("e.g. 50 min", text: $vm.recipe.totalTime)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Servings") {
                    TextField("e.g. 4 servings", text: $vm.recipe.servings)
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
                TextEditor(text: $vm.recipe.description)
                    .frame(minHeight: 60)
                    .font(.body)
            }

            Section("Notes") {
                TextEditor(text: $vm.recipe.notes)
                    .frame(minHeight: 60)
                    .font(.body)
            }

            Section("Nutritional Info") {
                TextEditor(text: $vm.recipe.nutritionalInfo)
                    .frame(minHeight: 60)
                    .font(.body)
            }

            Section("Source") {
                TextField("Source name", text: $vm.recipe.source)
                TextField("URL", text: $vm.recipe.sourceURL)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }

            Section {
                Button {
                    handleExport()
                } label: {
                    Label("Export to Paprika", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                        .bold()
                }
                .buttonStyle(.borderedProminent)
                .disabled(vm.recipe.name.isEmpty)
            }
        }
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
            let url = try vm.createExportFile()
            onExport(url)
        } catch {
            exportError = error.localizedDescription
        }
    }

    private var ingredientsBinding: Binding<String> {
        Binding(
            get: { vm.recipe.ingredients.joined(separator: "\n") },
            set: { vm.recipe.ingredients = $0.components(separatedBy: "\n").filter { !$0.isEmpty } }
        )
    }

    private var directionsBinding: Binding<String> {
        Binding(
            get: { vm.recipe.directions.joined(separator: "\n\n") },
            set: { vm.recipe.directions = $0.components(separatedBy: "\n\n").filter { !$0.isEmpty } }
        )
    }

    private var categoriesBinding: Binding<String> {
        Binding(
            get: { vm.recipe.categories.joined(separator: ", ") },
            set: {
                vm.recipe.categories = $0
                    .components(separatedBy: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
            }
        )
    }
}
