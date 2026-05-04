import SwiftUI

struct MainRecipeListView: View {
    @Environment(RecipeStore.self) private var store
    @State private var showNewRecipe = false

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    var body: some View {
        NavigationStack {
            Group {
                if store.recipes.isEmpty {
                    emptyState
                } else {
                    recipeList
                }
            }
            .navigationTitle("PaprikAI")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showNewRecipe = true
                    } label: {
                        Label("New Recipe", systemImage: "plus")
                    }
                }
            }
            .fullScreenCover(isPresented: $showNewRecipe) {
                NewRecipeFlowView(store: store)
            }
        }
    }

    private var recipeList: some View {
        List {
            ForEach(store.recipes) { recipe in
                NavigationLink(destination: RecipeDetailView(recipe: recipe)) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(recipe.name.isEmpty ? "Untitled Recipe" : recipe.name)
                            .font(.headline)
                        Text(Self.dateFormatter.string(from: recipe.createdAt))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .onDelete(perform: store.remove)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "fork.knife.circle")
                .font(.system(size: 72))
                .foregroundStyle(.secondary)
            Text("No Recipes Yet")
                .font(.title2)
                .bold()
            Text("Tap + to photograph a recipe\nand export it to Paprika.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                showNewRecipe = true
            } label: {
                Label("New Recipe", systemImage: "camera")
                    .bold()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
