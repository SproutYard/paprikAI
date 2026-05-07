import SwiftUI
import UIKit

struct CameraPicker: UIViewControllerRepresentable {
    @Binding var images: [UIImage]
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.showsCameraControls = false
        picker.delegate = context.coordinator
        context.coordinator.picker = picker

        let overlay = CameraOverlayView(coordinator: context.coordinator)
        overlay.frame = UIScreen.main.bounds
        context.coordinator.overlay = overlay
        picker.cameraOverlayView = overlay

        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        weak var picker: UIImagePickerController?
        weak var overlay: CameraOverlayView?
        private var capturedPhotos: [UIImage] = []

        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                capturedPhotos.append(image)
                overlay?.photoAdded(image)
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }

        func takePicture() { picker?.takePicture() }

        func removePhoto(at index: Int) {
            guard index < capturedPhotos.count else { return }
            capturedPhotos.remove(at: index)
        }

        func done() {
            parent.images.append(contentsOf: capturedPhotos)
            parent.dismiss()
        }

        func cancel() { parent.dismiss() }
    }
}

final class CameraOverlayView: UIView {
    private weak var coordinator: CameraPicker.Coordinator?

    private let thumbnailScrollView = UIScrollView()
    private let thumbnailStack = UIStackView()
    private let toolbar = UIView()
    private let shutterButton = UIButton(type: .custom)
    private let doneButton = UIButton(type: .system)
    private let cancelButton = UIButton(type: .system)

    private var capturedPhotos: [UIImage] = []

    private let toolbarH: CGFloat = 130
    private let thumbStripH: CGFloat = 96

    init(coordinator: CameraPicker.Coordinator) {
        self.coordinator = coordinator
        super.init(frame: .zero)
        backgroundColor = .clear
        setupSubviews()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupSubviews() {
        // Thumbnail strip
        thumbnailScrollView.showsHorizontalScrollIndicator = false
        thumbnailScrollView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        thumbnailScrollView.isHidden = true
        addSubview(thumbnailScrollView)

        thumbnailStack.axis = .horizontal
        thumbnailStack.spacing = 8
        thumbnailStack.alignment = .center
        thumbnailStack.translatesAutoresizingMaskIntoConstraints = false
        thumbnailScrollView.addSubview(thumbnailStack)

        NSLayoutConstraint.activate([
            thumbnailStack.topAnchor.constraint(equalTo: thumbnailScrollView.contentLayoutGuide.topAnchor, constant: 8),
            thumbnailStack.bottomAnchor.constraint(equalTo: thumbnailScrollView.contentLayoutGuide.bottomAnchor, constant: -8),
            thumbnailStack.leadingAnchor.constraint(equalTo: thumbnailScrollView.contentLayoutGuide.leadingAnchor, constant: 8),
            thumbnailStack.trailingAnchor.constraint(equalTo: thumbnailScrollView.contentLayoutGuide.trailingAnchor, constant: -8),
            thumbnailStack.heightAnchor.constraint(equalTo: thumbnailScrollView.frameLayoutGuide.heightAnchor, constant: -16),
        ])

        // Toolbar
        toolbar.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        addSubview(toolbar)

        shutterButton.backgroundColor = .white
        shutterButton.layer.borderColor = UIColor.white.cgColor
        shutterButton.layer.borderWidth = 4
        shutterButton.addTarget(self, action: #selector(shutterTapped), for: .touchUpInside)
        toolbar.addSubview(shutterButton)

        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.setTitleColor(.white, for: .normal)
        cancelButton.titleLabel?.font = .systemFont(ofSize: 17)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        toolbar.addSubview(cancelButton)

        doneButton.setTitle("Done", for: .normal)
        doneButton.setTitleColor(.white, for: .normal)
        doneButton.setTitleColor(UIColor.white.withAlphaComponent(0.3), for: .disabled)
        doneButton.titleLabel?.font = .boldSystemFont(ofSize: 17)
        doneButton.isEnabled = false
        doneButton.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)
        toolbar.addSubview(doneButton)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let hasPhotos = !capturedPhotos.isEmpty
        let stripH: CGFloat = hasPhotos ? thumbStripH : 0

        toolbar.frame = CGRect(x: 0, y: bounds.height - toolbarH, width: bounds.width, height: toolbarH)
        thumbnailScrollView.frame = CGRect(x: 0, y: bounds.height - toolbarH - stripH, width: bounds.width, height: stripH)

        let shutterSize: CGFloat = 68
        let buttonY: CGFloat = 16
        shutterButton.frame = CGRect(
            x: (toolbar.bounds.width - shutterSize) / 2,
            y: buttonY,
            width: shutterSize,
            height: shutterSize
        )
        shutterButton.layer.cornerRadius = shutterSize / 2

        cancelButton.sizeToFit()
        cancelButton.center = CGPoint(
            x: 24 + cancelButton.bounds.width / 2,
            y: shutterButton.center.y
        )

        doneButton.sizeToFit()
        doneButton.center = CGPoint(
            x: toolbar.bounds.width - 24 - doneButton.bounds.width / 2,
            y: shutterButton.center.y
        )
    }

    func photoAdded(_ image: UIImage) {
        capturedPhotos.append(image)
        rebuildThumbnails()
        doneButton.isEnabled = true

        UIView.animate(withDuration: 0.08, animations: { self.shutterButton.alpha = 0.3 }) { _ in
            UIView.animate(withDuration: 0.08) { self.shutterButton.alpha = 1.0 }
        }
    }

    private func removePhotoAt(_ index: Int) {
        capturedPhotos.remove(at: index)
        coordinator?.removePhoto(at: index)
        rebuildThumbnails()
        doneButton.isEnabled = !capturedPhotos.isEmpty
        setNeedsLayout()
    }

    private func rebuildThumbnails() {
        thumbnailStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (i, image) in capturedPhotos.enumerated() {
            thumbnailStack.addArrangedSubview(makeThumbnailView(image: image, index: i))
        }
        thumbnailScrollView.isHidden = capturedPhotos.isEmpty
        setNeedsLayout()

        DispatchQueue.main.async {
            let maxX = max(0, self.thumbnailScrollView.contentSize.width - self.thumbnailScrollView.bounds.width)
            self.thumbnailScrollView.setContentOffset(CGPoint(x: maxX, y: 0), animated: true)
        }
    }

    private func makeThumbnailView(image: UIImage, index: Int) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 8
        imageView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(imageView)

        let xButton = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        xButton.setImage(UIImage(systemName: "xmark.circle.fill", withConfiguration: config), for: .normal)
        xButton.tintColor = .white
        xButton.translatesAutoresizingMaskIntoConstraints = false
        xButton.addAction(UIAction { [weak self] _ in
            self?.removePhotoAt(index)
        }, for: .touchUpInside)
        container.addSubview(xButton)

        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(equalToConstant: 80),

            imageView.topAnchor.constraint(equalTo: container.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            xButton.topAnchor.constraint(equalTo: container.topAnchor, constant: -6),
            xButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: 6),
        ])

        return container
    }

    @objc private func shutterTapped() { coordinator?.takePicture() }
    @objc private func doneTapped() { coordinator?.done() }
    @objc private func cancelTapped() { coordinator?.cancel() }
}
