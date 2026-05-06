import Testing
import Foundation
@testable import PaprikAI

struct YAMLExportTests {

    private let service = PaprikaExportService()

    private func yaml(for recipe: ExtractedRecipe) throws -> String {
        let url = try service.exportYAML(recipe: recipe)
        defer { try? FileManager.default.removeItem(at: url) }
        return try String(contentsOf: url, encoding: .utf8)
    }

    // MARK: - Scalar fields

    @Test func scalarFieldsAreQuoted() throws {
        let recipe = ExtractedRecipe(
            name: "Banana Bread",
            servings: "8 slices",
            prepTime: "15 min",
            cookTime: "60 min",
            totalTime: "75 min",
            source: "Grandma",
            sourceURL: "https://example.com"
        )
        let out = try yaml(for: recipe)
        #expect(out.contains(#"name: "Banana Bread""#))
        #expect(out.contains(#"servings: "8 slices""#))
        #expect(out.contains(#"prep_time: "15 min""#))
        #expect(out.contains(#"cook_time: "60 min""#))
        #expect(out.contains(#"total_time: "75 min""#))
        #expect(out.contains(#"source: "Grandma""#))
        #expect(out.contains(#"source_url: "https://example.com""#))
    }

    @Test func emptyScalarFieldsAreOmitted() throws {
        let recipe = ExtractedRecipe(name: "Minimal", source: "")
        let out = try yaml(for: recipe)
        #expect(!out.contains("servings:"))
        #expect(!out.contains("prep_time:"))
        #expect(!out.contains("cook_time:"))
        #expect(!out.contains("total_time:"))
        #expect(!out.contains("source:"))
        #expect(!out.contains("source_url:"))
        #expect(!out.contains("categories:"))
    }

    @Test func backslashEscapedInScalar() throws {
        let recipe = ExtractedRecipe(name: #"C:\Users\recipe"#, source: "")
        let out = try yaml(for: recipe)
        #expect(out.contains(#"name: "C:\\Users\\recipe""#))
    }

    @Test func doubleQuoteEscapedInScalar() throws {
        let recipe = ExtractedRecipe(name: #"Say "hello""#, source: "")
        let out = try yaml(for: recipe)
        #expect(out.contains(#"name: "Say \"hello\"""#))
    }

    // MARK: - Block fields

    @Test func blockFieldsUseBarScalar() throws {
        let recipe = ExtractedRecipe(
            name: "Test",
            description: "Rich and chocolatey",
            notes: "Keep refrigerated",
            nutritionalInfo: "200 cal per serving"
        )
        let out = try yaml(for: recipe)
        #expect(out.contains("description: |\n  Rich and chocolatey"))
        #expect(out.contains("notes: |\n  Keep refrigerated"))
        #expect(out.contains("nutritional_info: |\n  200 cal per serving"))
    }

    @Test func emptyBlockFieldsAreOmitted() throws {
        let recipe = ExtractedRecipe(name: "Minimal")
        let out = try yaml(for: recipe)
        #expect(!out.contains("description:"))
        #expect(!out.contains("nutritional_info:"))
        #expect(!out.contains("notes:"))
        #expect(!out.contains("ingredients:"))
        #expect(!out.contains("directions:"))
    }

    // MARK: - Ingredients

    @Test func ingredientsJoinedWithSingleNewline() throws {
        let recipe = ExtractedRecipe(
            name: "Test",
            ingredients: ["1 cup flour", "2 eggs", "1/2 cup sugar"]
        )
        let out = try yaml(for: recipe)
        #expect(out.contains("ingredients: |\n  1 cup flour\n  2 eggs\n  1/2 cup sugar"))
    }

    // MARK: - Directions

    @Test func directionsJoinedWithDoubleNewline() throws {
        let recipe = ExtractedRecipe(
            name: "Test",
            directions: ["Preheat oven to 350°F", "Mix dry ingredients", "Bake 30 min"]
        )
        let out = try yaml(for: recipe)
        #expect(out.contains("directions: |\n  Preheat oven to 350°F\n\n  Mix dry ingredients\n\n  Bake 30 min"))
    }

    @Test func directionSeparatorLacksTrailingWhitespace() throws {
        // Blank lines between directions must not have trailing spaces (YAML spec compliance)
        let recipe = ExtractedRecipe(name: "Test", directions: ["Step 1", "Step 2"])
        let out = try yaml(for: recipe)
        #expect(out.contains("  Step 1\n\n  Step 2"))
        #expect(!out.contains("  Step 1\n  \n  Step 2"))
    }

    // MARK: - Categories

    @Test func categoriesJoinedWithCommaSpace() throws {
        let recipe = ExtractedRecipe(
            name: "Test",
            categories: ["Desserts", "Cookies", "Baking"]
        )
        let out = try yaml(for: recipe)
        #expect(out.contains(#"categories: "Desserts, Cookies, Baking""#))
    }

    @Test func emptyCategoriesOmitted() throws {
        let recipe = ExtractedRecipe(name: "Test", categories: [])
        let out = try yaml(for: recipe)
        #expect(!out.contains("categories:"))
    }

    // MARK: - File output

    @Test func fileHasYmlExtension() throws {
        let recipe = ExtractedRecipe(name: "My Recipe")
        let url = try service.exportYAML(recipe: recipe)
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(url.pathExtension == "yml")
    }

    @Test func filenameMatchesRecipeName() throws {
        let recipe = ExtractedRecipe(name: "Chocolate Cake")
        let url = try service.exportYAML(recipe: recipe)
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(url.lastPathComponent == "Chocolate Cake.yml")
    }

    @Test func filenameSanitizesForbiddenChars() throws {
        let recipe = ExtractedRecipe(name: "Recipe: A/B*C?D")
        let url = try service.exportYAML(recipe: recipe)
        defer { try? FileManager.default.removeItem(at: url) }
        let name = url.lastPathComponent
        #expect(!name.contains(":"))
        #expect(!name.contains("*"))
        #expect(!name.contains("?"))
    }

    @Test func emptyNameDefaultsToRecipeFilename() throws {
        let recipe = ExtractedRecipe(name: "")
        let url = try service.exportYAML(recipe: recipe)
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(url.lastPathComponent == "Recipe.yml")
    }

    @Test func fileExistsAtReturnedURL() throws {
        let recipe = ExtractedRecipe(name: "Test")
        let url = try service.exportYAML(recipe: recipe)
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(FileManager.default.fileExists(atPath: url.path))
    }

    @Test func outputEndsWithNewline() throws {
        let recipe = ExtractedRecipe(name: "Test")
        let out = try yaml(for: recipe)
        #expect(out.hasSuffix("\n"))
    }
}
