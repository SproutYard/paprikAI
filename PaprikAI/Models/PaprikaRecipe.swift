import Foundation

// Property order matches the Paprika JSON schema exactly (verified against example file).
struct PaprikaRecipe: Codable {
    var name: String
    var hash: String
    var directions: String
    var source_url: String
    var description: String
    var photo_hash: String
    var photo: String
    var total_time: String
    var nutritional_info: String
    var image_url: String
    var servings: String
    var uid: String
    var created: String
    var rating: Int
    var prep_time: String
    var categories: [String]
    var source: String
    var cook_time: String
    var photo_data: String
    var ingredients: String
    var photos: [String]
    var difficulty: String
    var photo_large: String?
    var notes: String
}
