import SwiftUI
import PhotosUI

struct PhotoReviewView: View {
    @Bindable var vm: NewRecipeViewModel
    @State private var showCamera = false
    @State private var pickerItems: [PhotosPickerItem] = []

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 8)]

    var body: some View {
        VStack(spacing: 0) {
            if vm.photos.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(Array(vm.photos.enumerated()), id: \.offset) { index, photo in
                            thumbnail(photo, at: index)
                        }
                    }
                    .padding()
                }
            }

            Divider()

            bottomBar
        }
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            Task {
                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        vm.photos.append(image)
                    }
                }
                pickerItems = []
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker(images: $vm.photos)
                .ignoresSafeArea()
        }
    }

    private func thumbnail(_ photo: UIImage, at index: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: photo)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            Button {
                vm.photos.remove(at: index)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, Color.black.opacity(0.65))
            }
            .padding(4)
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Button {
                showCamera = true
            } label: {
                Label("Camera", systemImage: "camera")
            }
            .buttonStyle(.bordered)

            PhotosPicker(selection: $pickerItems, maxSelectionCount: 10, matching: .images) {
                Label("Library", systemImage: "photo.on.rectangle")
            }
            .buttonStyle(.bordered)

            Spacer()

            Button {
                Task { await vm.processPhotos() }
            } label: {
                Text("Process Recipe")
                    .bold()
            }
            .buttonStyle(.borderedProminent)
            .disabled(vm.photos.isEmpty)
        }
        .padding()
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            Text("Add photos of your recipe")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Use the camera or pick from your library below.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
