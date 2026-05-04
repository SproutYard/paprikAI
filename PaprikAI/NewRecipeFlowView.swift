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

    func createYAMLExportFile() throws -> URL {
        try PaprikaExportService().exportYAML(recipe: recipe)
    }

    func createPaprikaExportFile() throws -> URL {
        try PaprikaExportService().exportPaprika(recipe: recipe, photo: photos.first)
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
                presentShareSheet(items: [url]) {
                    store.add(vm.recipe)
                    dismiss()
                }
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

// MARK: - Share sheet helper

/// Presents UIActivityViewController directly on the UIKit hierarchy, avoiding
/// the blank-overlay issue caused by nesting it inside a SwiftUI sheet.
func presentShareSheet(items: [Any], onDismiss: @escaping @MainActor () -> Void = {}) {
    guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else { return }

    var top = root
    while let next = top.presentedViewController { top = next }

    let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
    vc.completionWithItemsHandler = { _, _, _, _ in
        Task { @MainActor in onDismiss() }
    }

    if let popover = vc.popoverPresentationController {
        popover.sourceView = top.view
        popover.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.midY, width: 0, height: 0)
        popover.permittedArrowDirections = []
    }

    top.present(vc, animated: true)
}
