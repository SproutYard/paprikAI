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
        let photo = photos.indices.contains(recipe.selectedPhotoIndex)
            ? photos[recipe.selectedPhotoIndex]
            : photos.first
        return try PaprikaExportService().exportPaprika(recipe: recipe, photo: photo)
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
        PhotoDeckProcessingView(photos: vm.photos)
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

// MARK: - Processing animation

private struct PhotoDeckProcessingView: View {
    let photos: [UIImage]

    private var displayPhotos: [UIImage] { Array(photos.prefix(3)) }
    private let rotations: [Double] = [-3, -14, 12]
    private let xOffsets: [CGFloat] = [0, -85, 85]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            TimelineView(.animation) { ctx in
                photoStack(t: ctx.date.timeIntervalSinceReferenceDate)
            }
            Spacer().frame(height: 44)
            VStack(spacing: 8) {
                ProgressView().tint(.purple)
                Text("Extracting recipe…")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func photoStack(t: Double) -> some View {
        ZStack {
            ForEach(Array(displayPhotos.enumerated()), id: \.offset) { i, photo in
                let phase = Double(i) * 1.8
                let floatY = CGFloat(sin(t * 0.6 + phase) * 13)
                let xDrift = CGFloat(sin(t * 0.45 + phase) * 8)
                let wobble = sin(t * 0.3 + phase) * 2.0
                let shimmerX: CGFloat = i == 0 ? CGFloat(sin(t * 0.7) * 155) : -300

                PolaroidCard(image: photo, shimmerX: shimmerX)
                    .rotationEffect(.degrees(rotations[i % rotations.count] + wobble))
                    .offset(x: xOffsets[i % xOffsets.count] + xDrift, y: floatY)
                    .zIndex(Double(photos.count - i))
            }
        }
        .frame(height: 300)
    }
}

private struct PolaroidCard: View {
    let image: UIImage
    let shimmerX: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 180, height: 170)

                LinearGradient(
                    colors: [.clear, .white.opacity(0.22), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 90)
                .offset(x: shimmerX)
            }
            .frame(width: 180, height: 170)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.black.opacity(0.07), lineWidth: 1)
            )

            // Polaroid bottom strip
            Rectangle()
                .fill(Color(white: 0.98))
                .frame(width: 180, height: 46)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(white: 0.975))
                .shadow(color: .black.opacity(0.22), radius: 12, x: 1, y: 6)
        )
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
