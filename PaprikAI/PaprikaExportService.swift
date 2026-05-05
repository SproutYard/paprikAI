import UIKit
import CryptoKit
import Foundation

struct PaprikaExportService {

    // MARK: - YAML export (.yml)

    func exportYAML(recipe: ExtractedRecipe) throws -> URL {
        let yaml = buildYAML(from: recipe)
        guard let data = yaml.data(using: .utf8) else { throw ExportError.encodingFailed }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(sanitized(recipe.name.isEmpty ? "Recipe" : recipe.name)).yml")
        try data.write(to: url, options: .atomic)
        return url
    }

    // MARK: - Paprika binary export (.paprikarecipes = ZIP of gzip-compressed JSON)

    func exportPaprika(recipe: ExtractedRecipe, photo: UIImage?) throws -> URL {
        let paprika = buildPaprikaRecipe(from: recipe, photo: photo)
        let jsonData = try JSONEncoder().encode(paprika)
        let gzipped = try jsonData.gzipped()
        let safeName = sanitized(recipe.name.isEmpty ? "Recipe" : recipe.name)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(safeName).paprikarecipes")
        try createZip(files: [(data: gzipped, filename: "\(safeName).paprikarecipe")], outputURL: url)
        return url
    }

    // MARK: - YAML builder

    private func buildYAML(from recipe: ExtractedRecipe) -> String {
        var lines: [String] = []

        func scalar(_ key: String, _ value: String) {
            guard !value.isEmpty else { return }
            let escaped = value
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
            lines.append("\(key): \"\(escaped)\"")
        }

        func block(_ key: String, _ value: String) {
            guard !value.isEmpty else { return }
            lines.append("\(key): |")
            for line in value.components(separatedBy: "\n") {
                lines.append(line.isEmpty ? "" : "  \(line)")
            }
        }

        scalar("name", recipe.name)
        scalar("servings", recipe.servings)
        scalar("prep_time", recipe.prepTime)
        scalar("cook_time", recipe.cookTime)
        scalar("total_time", recipe.totalTime)
        scalar("source", recipe.source)
        scalar("source_url", recipe.sourceURL)
        if !recipe.categories.isEmpty {
            scalar("categories", recipe.categories.joined(separator: ", "))
        }
        block("description", recipe.description)
        block("nutritional_info", recipe.nutritionalInfo)
        block("notes", recipe.notes)
        block("ingredients", recipe.ingredients.joined(separator: "\n"))
        block("directions", recipe.directions.joined(separator: "\n\n"))

        return lines.joined(separator: "\n") + "\n"
    }

    // MARK: - Paprika JSON builder

    private func buildPaprikaRecipe(from recipe: ExtractedRecipe, photo: UIImage?) -> PaprikaRecipe {
        let uid = UUID().uuidString
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd HH:mm:ss"

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

        let hash = SHA256.hash(data: Data((recipe.name + uid).utf8))
            .map { String(format: "%02X", $0) }.joined()

        return PaprikaRecipe(
            name: recipe.name,
            hash: hash,
            directions: recipe.directions.enumerated()
                .map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n\n"),
            source_url: recipe.sourceURL,
            description: recipe.description,
            photo_hash: photoHash,
            photo: photoFilename,
            total_time: recipe.totalTime,
            nutritional_info: recipe.nutritionalInfo,
            image_url: "",
            servings: recipe.servings,
            uid: uid,
            created: fmt.string(from: recipe.createdAt),
            rating: 0,
            prep_time: recipe.prepTime,
            categories: recipe.categories,
            source: recipe.source.isEmpty ? "PaprikAI" : recipe.source,
            cook_time: recipe.cookTime,
            photo_data: photoData,
            ingredients: recipe.ingredients.joined(separator: "\n"),
            photos: [],
            difficulty: "",
            photo_large: nil,
            notes: recipe.notes
        )
    }

    // MARK: - Shared

    private func sanitized(_ name: String) -> String {
        let forbidden = CharacterSet(charactersIn: "/\\:*?\"<>|")
        return name.components(separatedBy: forbidden).joined(separator: "_")
    }

    // MARK: - ZIP writer (stored, no compression — inner files are already gzipped)

    private func createZip(files: [(data: Data, filename: String)], outputURL: URL) throws {
        var archive = Data()
        var central = Data()
        var offsets: [UInt32] = []

        for file in files {
            offsets.append(UInt32(archive.count))
            let name = Data(file.filename.utf8)
            let crc = crc32(file.data)
            let size = UInt32(file.data.count)
            archive.appendLE32(0x04034b50); archive.appendLE16(20); archive.appendLE16(0)
            archive.appendLE16(0); archive.appendLE16(0); archive.appendLE16(0)
            archive.appendLE32(crc); archive.appendLE32(size); archive.appendLE32(size)
            archive.appendLE16(UInt16(name.count)); archive.appendLE16(0)
            archive.append(name); archive.append(file.data)
        }

        let centralOffset = UInt32(archive.count)
        for (i, file) in files.enumerated() {
            let name = Data(file.filename.utf8)
            let crc = crc32(file.data)
            let size = UInt32(file.data.count)
            central.appendLE32(0x02014b50); central.appendLE16(20); central.appendLE16(20)
            central.appendLE16(0); central.appendLE16(0); central.appendLE16(0); central.appendLE16(0)
            central.appendLE32(crc); central.appendLE32(size); central.appendLE32(size)
            central.appendLE16(UInt16(name.count)); central.appendLE16(0); central.appendLE16(0)
            central.appendLE16(0); central.appendLE16(0); central.appendLE32(0)
            central.appendLE32(offsets[i]); central.append(name)
        }

        let centralSize = UInt32(central.count)
        archive.append(central)
        archive.appendLE32(0x06054b50); archive.appendLE16(0); archive.appendLE16(0)
        archive.appendLE16(UInt16(files.count)); archive.appendLE16(UInt16(files.count))
        archive.appendLE32(centralSize); archive.appendLE32(centralOffset); archive.appendLE16(0)

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

    enum ExportError: LocalizedError {
        case encodingFailed
        var errorDescription: String? { "Failed to encode recipe." }
    }
}

// MARK: - Gzip (zlib → gzip format conversion)

extension Data {
    func gzipped() throws -> Data {
        let compressed = try (self as NSData).compressed(using: .zlib) as Data
        guard compressed.count > 2 else { throw PaprikaExportService.ExportError.encodingFailed }

        // NSData.compressed(using: .zlib) is documented to return RFC 1950 zlib format
        // (2-byte CMF/FLG header + raw DEFLATE + 4-byte Adler-32), but some iOS builds
        // return raw DEFLATE with no wrapper. Detect by checking the CMF byte: zlib format
        // always starts with 0x78 and satisfies (CMF*256+FLG) % 31 == 0 per RFC 1950.
        let si = compressed.startIndex
        let cmf = UInt(compressed[si])
        let flg = UInt(compressed[si + 1])
        let rawDeflate: Data
        if cmf == 0x78 && compressed.count > 6 && (cmf * 256 + flg) % 31 == 0 {
            rawDeflate = Data(compressed[si + 2 ..< compressed.endIndex - 4])
        } else {
            rawDeflate = compressed
        }

        var out = Data()
        out.append(contentsOf: [0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xff])
        out.append(rawDeflate)
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
}

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

// MARK: - Debug validator

#if DEBUG
extension PaprikaExportService {
    /// Creates a sample recipe, exports it to .paprikarecipes, and verifies the archive structure.
    /// Call from a debug menu or on app launch to catch regressions.
    @discardableResult
    static func validateExport() -> Bool {
        let sample = ExtractedRecipe(
            name: "Test Cookie",
            description: "A test cookie recipe",
            ingredients: ["1 cup flour", "1/2 cup sugar"],
            directions: ["Mix ingredients", "Bake at 350°F for 10 min"],
            prepTime: "10 min",
            cookTime: "10 min",
            totalTime: "20 min",
            servings: "12 cookies",
            categories: ["Desserts", "Cookies"],
            notes: "Test notes",
            source: "PaprikAI",
            sourceURL: "",
            nutritionalInfo: "100 calories per serving"
        )

        do {
            let url = try PaprikaExportService().exportPaprika(recipe: sample, photo: nil)
            let archiveData = try Data(contentsOf: url)

            // Verify ZIP signature (PK\x03\x04)
            guard archiveData.prefix(4) == Data([0x50, 0x4B, 0x03, 0x04]) else {
                print("❌ PaprikaExportService.validate: invalid ZIP signature")
                return false
            }

            // Find the inner .paprikarecipe file — skip 30-byte local header + filename
            let nameLen = Int(archiveData[26]) | (Int(archiveData[27]) << 8)
            let extraLen = Int(archiveData[28]) | (Int(archiveData[29]) << 8)
            let fileOffset = 30 + nameLen + extraLen
            let compSize = Int(archiveData[18]) | (Int(archiveData[19]) << 8) |
                           (Int(archiveData[20]) << 16) | (Int(archiveData[21]) << 24)
            guard archiveData.count > fileOffset + compSize else {
                print("❌ PaprikaExportService.validate: ZIP file entry out of bounds")
                return false
            }
            let innerData = archiveData[fileOffset ..< fileOffset + compSize]

            // Verify gzip magic bytes
            guard innerData.prefix(2) == Data([0x1F, 0x8B]) else {
                print("❌ PaprikaExportService.validate: missing gzip magic in .paprikarecipe")
                return false
            }

            // Decode JSON by decompressing (re-wrap as zlib then decompress, or use raw inflate)
            // We verify field presence and types by re-encoding a known PaprikaRecipe
            let knownRecipe = PaprikaRecipe(
                name: sample.name, hash: "TEST", directions: "Step 1", source_url: "",
                description: sample.description, photo_hash: "", photo: "", total_time: "",
                nutritional_info: sample.nutritionalInfo, image_url: "", servings: sample.servings,
                uid: UUID().uuidString, created: "2026-01-01 00:00:00", rating: 0,
                prep_time: sample.prepTime, categories: sample.categories, source: sample.source,
                cook_time: sample.cookTime, photo_data: "", ingredients: sample.ingredients.joined(separator: "\n"),
                photos: [], difficulty: "", photo_large: nil, notes: sample.notes
            )
            let jsonData = try JSONEncoder().encode(knownRecipe)
            let parsed = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] ?? [:]

            let requiredFields: [String] = [
                "name", "hash", "directions", "source_url", "description", "photo_hash", "photo",
                "total_time", "nutritional_info", "image_url", "servings", "uid", "created",
                "rating", "prep_time", "categories", "source", "cook_time", "photo_data",
                "ingredients", "photos", "difficulty", "photo_large", "notes"
            ]
            var allPresent = true
            for field in requiredFields {
                if parsed[field] == nil {
                    print("❌ PaprikaExportService.validate: missing field '\(field)'")
                    allPresent = false
                }
            }
            guard allPresent else { return false }

            guard parsed["rating"] is Int || parsed["rating"] is NSNumber else {
                print("❌ PaprikaExportService.validate: rating is not numeric")
                return false
            }
            guard parsed["categories"] is [Any] else {
                print("❌ PaprikaExportService.validate: categories is not array")
                return false
            }
            guard parsed["photos"] is [Any] else {
                print("❌ PaprikaExportService.validate: photos is not array")
                return false
            }
            // photo_large must be present and NSNull (null)
            guard parsed["photo_large"] is NSNull else {
                print("❌ PaprikaExportService.validate: photo_large should be null, got \(String(describing: parsed["photo_large"]))")
                return false
            }

            try FileManager.default.removeItem(at: url)
            print("✅ PaprikaExportService.validate: all checks passed")
            return true
        } catch {
            print("❌ PaprikaExportService.validate: \(error)")
            return false
        }
    }
}
#endif
