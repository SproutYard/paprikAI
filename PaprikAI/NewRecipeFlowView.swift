import SwiftUI
import Observation

// MARK: - ViewModel

@Observable
class NewRecipeViewModel {
    var photos: [UIImage] = []
    var recipe: ExtractedRecipe = ExtractedRecipe()
    var state: FlowState = .capture
    var errorMessage: String? = nil

    enum FlowState { case capture, processing, review }

    func processPhotos() async {
        state = .processing
        errorMessage = nil
        do {
            recipe = try await RecipeExtractionService().extract(from: photos)
            state = .review
        } catch {
            errorMessage = error.localizedDescription
            state = .capture
        }
    }

    func createExportFile() throws -> URL {
        try PaprikaExportService().export(recipe: recipe, photo: photos.first)
    }

    func reset() {
        photos = []
        recipe = ExtractedRecipe()
        state = .capture
        errorMessage = nil
    }
}

// MARK: - View

struct NewRecipeFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var vm = NewRecipeViewModel()
    @State private var shareURL: URL? = nil
    @State private var showShareSheet = false

    var store: RecipeStore

    var body: some View {
        NavigationStack {
            contentView
                .navigationTitle(navTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { cancelButton }
                .alert("Error", isPresented: showErrorBinding) {
                    Button("OK") { vm.errorMessage = nil }
                } message: {
                    Text(vm.errorMessage ?? "")
                }
                .sheet(isPresented: $showShareSheet, onDismiss: {
                    store.add(vm.recipe)
                    dismiss()
                }) {
                    if let url = shareURL {
                        ShareSheet(items: [url])
                    }
                }
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch vm.state {
        case .capture:
            PhotoReviewView(vm: vm)
        case .processing:
            processingView
        case .review:
            RecipeReviewView(vm: vm, onExport: { url in
                shareURL = url
                showShareSheet = true
            })
        }
    }

    private var processingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .controlSize(.large)
            Text("Extracting recipe…")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var navTitle: String {
        switch vm.state {
        case .capture: "New Recipe"
        case .processing: "Processing"
        case .review: "Review Recipe"
        }
    }

    @ToolbarContentBuilder
    private var cancelButton: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
        }
    }

    private var showErrorBinding: Binding<Bool> {
        Binding(get: { vm.errorMessage != nil }, set: { if !$0 { vm.errorMessage = nil } })
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
