import Testing
import Foundation
@testable import PaprikAI

struct PaprikaExportTests {

    private let service = PaprikaExportService()

    // Exports a recipe, reads the archive, and extracts the inner gzip blob from the first ZIP entry.
    private func parsedExport(for recipe: ExtractedRecipe = .sample) throws -> (archive: Data, inner: Data, url: URL) {
        let url = try service.exportPaprika(recipe: recipe, photo: nil)
        let archive = try Data(contentsOf: url)
        // ZIP local file header: bytes 26-27 = name length, 28-29 = extra length
        let nameLen  = Int(archive[26]) | (Int(archive[27]) << 8)
        let extraLen = Int(archive[28]) | (Int(archive[29]) << 8)
        let offset   = 30 + nameLen + extraLen
        // Compressed size at bytes 18-21 (stored entries: compressed == uncompressed)
        let size = Int(archive[18]) | (Int(archive[19]) << 8) |
                   (Int(archive[20]) << 16) | (Int(archive[21]) << 24)
        return (archive, Data(archive[offset ..< offset + size]), url)
    }

    private func encodedJSON(for recipe: PaprikaRecipe) throws -> [String: Any] {
        let data = try JSONEncoder().encode(recipe)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }

    private func findSignature(_ bytes: [UInt8], in data: Data) -> Bool {
        guard data.count >= bytes.count else { return false }
        let sig = Data(bytes)
        for i in 0...(data.count - bytes.count) {
            if data[i ..< i + bytes.count] == sig { return true }
        }
        return false
    }

    private func crc32(_ data: Data) -> UInt32 {
        let table: [UInt32] = (0..<256).map { i -> UInt32 in
            (0..<8).reduce(UInt32(i)) { c, _ in (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1 }
        }
        return data.reduce(0xFFFFFFFF as UInt32) { crc, byte in
            table[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8)
        } ^ 0xFFFFFFFF
    }

    // MARK: - ZIP structure

    @Test func zipLocalHeaderSignature() throws {
        let (archive, _, url) = try parsedExport()
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(Data(archive[0..<4]) == Data([0x50, 0x4B, 0x03, 0x04]))
    }

    @Test func zipCompressionMethodIsStored() throws {
        let (archive, _, url) = try parsedExport()
        defer { try? FileManager.default.removeItem(at: url) }
        // Bytes 8-9: compression method — 0x0000 = stored (inner files are already gzipped)
        let method = UInt16(archive[8]) | (UInt16(archive[9]) << 8)
        #expect(method == 0)
    }

    @Test func zipCRCInHeaderMatchesActualData() throws {
        let (archive, inner, url) = try parsedExport()
        defer { try? FileManager.default.removeItem(at: url) }
        let storedCRC = UInt32(archive[14]) | (UInt32(archive[15]) << 8) |
                        (UInt32(archive[16]) << 16) | (UInt32(archive[17]) << 24)
        #expect(storedCRC == crc32(inner))
    }

    @Test func zipStoredSizeEqualsUncompressedSize() throws {
        let (archive, inner, url) = try parsedExport()
        defer { try? FileManager.default.removeItem(at: url) }
        let compressedSize   = UInt32(archive[18]) | (UInt32(archive[19]) << 8) |
                               (UInt32(archive[20]) << 16) | (UInt32(archive[21]) << 24)
        let uncompressedSize = UInt32(archive[22]) | (UInt32(archive[23]) << 8) |
                               (UInt32(archive[24]) << 16) | (UInt32(archive[25]) << 24)
        #expect(compressedSize == UInt32(inner.count))
        #expect(uncompressedSize == compressedSize)
    }

    @Test func zipInnerFilenameEndsInPaprikarecipe() throws {
        let (archive, _, url) = try parsedExport()
        defer { try? FileManager.default.removeItem(at: url) }
        let nameLen      = Int(archive[26]) | (Int(archive[27]) << 8)
        let filenameData = archive[30 ..< 30 + nameLen]
        let filename     = String(data: Data(filenameData), encoding: .utf8) ?? ""
        #expect(filename.hasSuffix(".paprikarecipe"))
    }

    @Test func zipCentralDirectoryPresent() throws {
        let (archive, _, url) = try parsedExport()
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(findSignature([0x50, 0x4B, 0x01, 0x02], in: archive))
    }

    @Test func zipEndOfCentralDirectoryPresent() throws {
        let (archive, _, url) = try parsedExport()
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(findSignature([0x50, 0x4B, 0x05, 0x06], in: archive))
    }

    // MARK: - Gzip format (inner file)

    @Test func gzipMagicBytes() throws {
        let (_, inner, url) = try parsedExport()
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(inner[0] == 0x1F && inner[1] == 0x8B)
    }

    @Test func gzipCompressionMethodIsDEFLATE() throws {
        let (_, inner, url) = try parsedExport()
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(inner[2] == 0x08)
    }

    @Test func gzipFlagsAreZero() throws {
        let (_, inner, url) = try parsedExport()
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(inner[3] == 0x00)
    }

    @Test func gzipOSFieldIsUnknown() throws {
        let (_, inner, url) = try parsedExport()
        defer { try? FileManager.default.removeItem(at: url) }
        // Byte 9: OS = 0xFF (unknown), as written by our gzip builder
        #expect(inner[9] == 0xFF)
    }

    @Test func gzipTrailerSizeIsNonZero() throws {
        let (_, inner, url) = try parsedExport()
        defer { try? FileManager.default.removeItem(at: url) }
        let isize = UInt32(inner[inner.count - 4]) | (UInt32(inner[inner.count - 3]) << 8) |
                    (UInt32(inner[inner.count - 2]) << 16) | (UInt32(inner[inner.count - 1]) << 24)
        #expect(isize > 0)
    }

    // MARK: - File naming

    @Test func fileExtensionIsPaprikarecipes() throws {
        let url = try service.exportPaprika(recipe: .sample, photo: nil)
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(url.pathExtension == "paprikarecipes")
    }

    @Test func filenameMatchesRecipeName() throws {
        let url = try service.exportPaprika(recipe: ExtractedRecipe(name: "Chocolate Cake"), photo: nil)
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(url.lastPathComponent == "Chocolate Cake.paprikarecipes")
    }

    @Test func emptyNameDefaultsToRecipeFilename() throws {
        let url = try service.exportPaprika(recipe: ExtractedRecipe(name: ""), photo: nil)
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(url.lastPathComponent == "Recipe.paprikarecipes")
    }

    @Test func filenameSanitizesForbiddenChars() throws {
        let url = try service.exportPaprika(recipe: ExtractedRecipe(name: #"A/B:C*D?E"<F>G|H"#), photo: nil)
        defer { try? FileManager.default.removeItem(at: url) }
        let name = url.lastPathComponent
        for ch: Character in ["/", ":", "*", "?", "\"", "<", ">", "|"] {
            #expect(!name.contains(ch), "Filename must not contain: \(ch)")
        }
    }

    @Test func fileExistsAtReturnedURL() throws {
        let url = try service.exportPaprika(recipe: .sample, photo: nil)
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(FileManager.default.fileExists(atPath: url.path))
    }

    // MARK: - PaprikaRecipe JSON encoding

    @Test func allTwentyFourFieldsEncoded() throws {
        let json = try encodedJSON(for: .sample)
        let required = [
            "name", "hash", "directions", "source_url", "description",
            "photo_hash", "photo", "total_time", "nutritional_info", "image_url",
            "servings", "uid", "created", "rating", "prep_time", "categories",
            "source", "cook_time", "photo_data", "ingredients", "photos",
            "difficulty", "photo_large", "notes"
        ]
        for field in required {
            #expect(json.keys.contains(field), "Missing field: \(field)")
        }
        #expect(json.count == 24)
    }

    // Paprika crashes on import when photo_large is absent rather than null.
    @Test func photoLargeIsExplicitlyNull() throws {
        let json = try encodedJSON(for: .sample)
        #expect(json.keys.contains("photo_large"), "photo_large key must be present")
        #expect(json["photo_large"] is NSNull, "photo_large must encode as null, not be omitted")
    }

    @Test func categoriesEncodesAsArray() throws {
        let json = try encodedJSON(for: .sample)
        #expect(json["categories"] is [Any])
    }

    @Test func photosEncodesAsEmptyArray() throws {
        let json = try encodedJSON(for: .sample)
        #expect((json["photos"] as? [Any])?.isEmpty == true)
    }

    @Test func ratingEncodesAsInteger() throws {
        let json = try encodedJSON(for: .sample)
        #expect((json["rating"] as? NSNumber)?.intValue == 0)
    }

    // MARK: - Round-trip validation (debug)

    #if DEBUG
    @Test func debugValidatorPasses() {
        #expect(PaprikaExportService.validateExport())
    }
    #endif
}

// MARK: - Test fixtures

extension ExtractedRecipe {
    static let sample = ExtractedRecipe(
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
}

extension PaprikaRecipe {
    static let sample = PaprikaRecipe(
        name: "Test Cookie",
        hash: "TESTHASH",
        directions: "1. Mix ingredients\n\n2. Bake at 350°F for 10 min",
        source_url: "",
        description: "A test cookie recipe",
        photo_hash: "",
        photo: "",
        total_time: "20 min",
        nutritional_info: "100 calories per serving",
        image_url: "",
        servings: "12 cookies",
        uid: "TEST-UUID",
        created: "2026-01-01 00:00:00",
        rating: 0,
        prep_time: "10 min",
        categories: ["Desserts", "Cookies"],
        source: "PaprikAI",
        cook_time: "10 min",
        photo_data: "",
        ingredients: "1 cup flour\n1/2 cup sugar",
        photos: [],
        difficulty: "",
        photo_large: nil,
        notes: "Test notes"
    )
}
