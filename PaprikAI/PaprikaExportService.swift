import UIKit
import CryptoKit
import Foundation

struct PaprikaExportService {

    func export(recipe: ExtractedRecipe, photo: UIImage?) throws -> URL {
        let paprika = buildPaprikaRecipe(from: recipe, photo: photo)

        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(paprika)

        let gzipped = try jsonData.gzipped()

        let safeName = sanitized(recipe.name.isEmpty ? "Recipe" : recipe.name)
        let recipeFilename = "\(safeName).paprikarecipe"
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("paprikarecipes")

        try createZip(
            files: [(data: gzipped, filename: recipeFilename)],
            outputURL: outputURL
        )

        return outputURL
    }

    private func buildPaprikaRecipe(from recipe: ExtractedRecipe, photo: UIImage?) -> PaprikaRecipe {
        let uid = UUID().uuidString

        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let created = fmt.string(from: recipe.createdAt)

        var photoData = ""
        var photoHash = ""
        var photoFilename = ""

        if let photo,
           let resized = photo.resized(toMaxDimension: 1200),
           let jpeg = resized.jpegData(compressionQuality: 0.82) {
            photoData = jpeg.base64EncodedString()
            photoHash = SHA256.hash(data: jpeg).map { String(format: "%02x", $0) }.joined()
            photoFilename = "\(uid).jpg"
        }

        let ingredientsStr = recipe.ingredients.joined(separator: "\n")

        let directionsStr = recipe.directions.enumerated()
            .map { "\($0.offset + 1). \($0.element)" }
            .joined(separator: "\n\n")

        let hashInput = Data((recipe.name + uid).utf8)
        let hash = SHA256.hash(data: hashInput).map { String(format: "%02X", $0) }.joined()

        return PaprikaRecipe(
            name: recipe.name,
            hash: hash,
            directions: directionsStr,
            source_url: recipe.sourceURL,
            description: recipe.description,
            photo_hash: photoHash,
            photo: photoFilename,
            total_time: recipe.totalTime,
            nutritional_info: recipe.nutritionalInfo,
            image_url: "",
            servings: recipe.servings,
            uid: uid,
            created: created,
            rating: 0,
            prep_time: recipe.prepTime,
            categories: recipe.categories,
            source: recipe.source.isEmpty ? "PaprikAI" : recipe.source,
            cook_time: recipe.cookTime,
            photo_data: photoData,
            ingredients: ingredientsStr,
            photos: [],
            difficulty: "",
            photo_large: nil,
            notes: recipe.notes
        )
    }

    private func sanitized(_ name: String) -> String {
        let forbidden = CharacterSet(charactersIn: "/\\:*?\"<>|")
        return name.components(separatedBy: forbidden).joined(separator: "_")
    }

    // Minimal ZIP writer using "stored" (method 0) — inner files are already gzipped.
    private func createZip(files: [(data: Data, filename: String)], outputURL: URL) throws {
        var archive = Data()
        var central = Data()
        var offsets: [UInt32] = []

        for file in files {
            offsets.append(UInt32(archive.count))
            let name = Data(file.filename.utf8)
            let crc = crc32(file.data)
            let size = UInt32(file.data.count)

            archive.appendLE32(0x04034b50)
            archive.appendLE16(20)
            archive.appendLE16(0)
            archive.appendLE16(0)     // stored
            archive.appendLE16(0)
            archive.appendLE16(0)
            archive.appendLE32(crc)
            archive.appendLE32(size)
            archive.appendLE32(size)
            archive.appendLE16(UInt16(name.count))
            archive.appendLE16(0)
            archive.append(name)
            archive.append(file.data)
        }

        let centralOffset = UInt32(archive.count)

        for (i, file) in files.enumerated() {
            let name = Data(file.filename.utf8)
            let crc = crc32(file.data)
            let size = UInt32(file.data.count)

            central.appendLE32(0x02014b50)
            central.appendLE16(20)
            central.appendLE16(20)
            central.appendLE16(0)
            central.appendLE16(0)     // stored
            central.appendLE16(0)
            central.appendLE16(0)
            central.appendLE32(crc)
            central.appendLE32(size)
            central.appendLE32(size)
            central.appendLE16(UInt16(name.count))
            central.appendLE16(0)
            central.appendLE16(0)
            central.appendLE16(0)
            central.appendLE16(0)
            central.appendLE32(0)
            central.appendLE32(offsets[i])
            central.append(name)
        }

        let centralSize = UInt32(central.count)
        archive.append(central)

        archive.appendLE32(0x06054b50)
        archive.appendLE16(0)
        archive.appendLE16(0)
        archive.appendLE16(UInt16(files.count))
        archive.appendLE16(UInt16(files.count))
        archive.appendLE32(centralSize)
        archive.appendLE32(centralOffset)
        archive.appendLE16(0)

        let dir = outputURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }
        try archive.write(to: outputURL)
    }

    private func crc32(_ data: Data) -> UInt32 {
        data.reduce(0xFFFFFFFF as UInt32) { crc, byte in
            crc32Table[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8)
        } ^ 0xFFFFFFFF
    }

    private let crc32Table: [UInt32] = (0..<256).map { i -> UInt32 in
        (0..<8).reduce(UInt32(i)) { c, _ in (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1 }
    }
}

// MARK: - Gzip

extension Data {
    // Converts from RFC 1950 zlib format to RFC 1952 gzip format.
    // NSData.compressed(using: .zlib) produces zlib: [2-byte header][deflate][4-byte adler32]
    // Gzip needs:                                    [10-byte header][deflate][4-byte crc32][4-byte size]
    func gzipped() throws -> Data {
        let zlib = try (self as NSData).compressed(using: .zlib) as Data
        guard zlib.count > 6 else { throw GzipError.failed }

        let deflate = zlib[2 ..< zlib.count - 4]

        var out = Data()
        out.append(contentsOf: [0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xff])
        out.append(deflate)

        var crc = self.reduce(0xFFFFFFFF as UInt32) { crc, byte in
            Data.gzipCRC32Table[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8)
        } ^ 0xFFFFFFFF

        Swift.withUnsafeBytes(of: crc.littleEndian) { out.append(contentsOf: $0) }
        var size = UInt32(truncatingIfNeeded: count)
        Swift.withUnsafeBytes(of: size.littleEndian) { out.append(contentsOf: $0) }

        return out
    }

    private static let gzipCRC32Table: [UInt32] = (0..<256).map { i -> UInt32 in
        (0..<8).reduce(UInt32(i)) { c, _ in (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1 }
    }

    enum GzipError: Error { case failed }
}

// MARK: - Helpers

extension Data {
    mutating func appendLE16(_ v: UInt16) { var x = v.littleEndian; append(Data(bytes: &x, count: 2)) }
    mutating func appendLE32(_ v: UInt32) { var x = v.littleEndian; append(Data(bytes: &x, count: 4)) }
}

extension UIImage {
    func resized(toMaxDimension maxDim: CGFloat) -> UIImage? {
        let scale = min(maxDim / size.width, maxDim / size.height, 1.0)
        if scale >= 1.0 { return self }
        let newSize = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        return UIGraphicsImageRenderer(size: newSize).image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
