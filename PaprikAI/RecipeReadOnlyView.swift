import SwiftUI

// MARK: - Pinned export bar

struct ExportButtonBar: View {
    let isDisabled: Bool
    let onYAML: () -> Void
    let onPaprika: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onYAML) {
                Text("YAML").bold().frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isDisabled)

            Button(action: onPaprika) {
                Text("Paprika").bold().frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .disabled(isDisabled)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial)
    }
}

// MARK: - Read-only recipe view

struct RecipeReadOnlyView: View {
    let recipe: ExtractedRecipe
    let onYAML: () -> Void
    let onPaprika: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(recipe.name.isEmpty ? "Untitled" : recipe.name)
                    .font(.title2).bold()
                    .padding(.bottom, 16)

                if !allMetadataEmpty {
                    metadataGrid
                        .padding(.bottom, 20)
                }

                if !recipe.categories.isEmpty {
                    sectionHeader("Categories")
                    Text(recipe.categories.joined(separator: ", "))
                        .font(.body)
                        .padding(.bottom, 20)
                }

                if !recipe.description.isEmpty {
                    sectionHeader("Description")
                    Text(recipe.description)
                        .font(.body)
                        .padding(.bottom, 20)
                }

                if !recipe.ingredients.isEmpty {
                    sectionHeader("Ingredients")
                    ingredientsList
                        .padding(.bottom, 20)
                }

                if !recipe.directions.isEmpty {
                    sectionHeader("Directions")
                    directionsList
                        .padding(.bottom, 20)
                }

                optionalSection("Notes", text: recipe.notes)
                optionalSection("Nutritional Info", text: recipe.nutritionalInfo)
                sourceSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
        }
        .safeAreaInset(edge: .bottom) {
            ExportButtonBar(
                isDisabled: recipe.name.isEmpty,
                onYAML: onYAML,
                onPaprika: onPaprika
            )
        }
    }

    // MARK: - Section helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(0.5)
            .padding(.bottom, 6)
    }

    private var metadataGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            if !recipe.prepTime.isEmpty  { metadataCell("Prep",     recipe.prepTime) }
            if !recipe.cookTime.isEmpty  { metadataCell("Cook",     recipe.cookTime) }
            if !recipe.totalTime.isEmpty { metadataCell("Total",    recipe.totalTime) }
            if !recipe.servings.isEmpty  { metadataCell("Servings", recipe.servings) }
        }
    }

    private func metadataCell(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var ingredientsList: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(recipe.ingredientRows.enumerated()), id: \.offset) { _, row in
                switch row {
                case .header(let title):
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .padding(.top, 8)
                        .padding(.bottom, 2)
                case .item(let text):
                    Text(text)
                        .font(.body)
                }
            }
        }
    }

    private var directionsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(recipe.directions.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("\(index + 1).")
                        .font(.body.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 24, alignment: .trailing)
                    Text(step)
                        .font(.body)
                }
            }
        }
    }

    @ViewBuilder
    private func optionalSection(_ title: String, text: String) -> some View {
        if !text.isEmpty {
            sectionHeader(title)
            Text(text)
                .font(.body)
                .padding(.bottom, 20)
        }
    }

    @ViewBuilder
    private var sourceSection: some View {
        let showSource = !recipe.source.isEmpty && recipe.source != "PaprikAI"
        let showURL = !recipe.sourceURL.isEmpty
        if showSource || showURL {
            sectionHeader("Source")
            VStack(alignment: .leading, spacing: 4) {
                if showSource {
                    Text(recipe.source).font(.body)
                }
                if showURL, let url = URL(string: recipe.sourceURL) {
                    Link(recipe.sourceURL, destination: url)
                        .font(.body)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .padding(.bottom, 20)
        }
    }

    private var allMetadataEmpty: Bool {
        recipe.prepTime.isEmpty && recipe.cookTime.isEmpty &&
        recipe.totalTime.isEmpty && recipe.servings.isEmpty
    }
}
