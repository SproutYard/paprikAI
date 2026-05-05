import Foundation

// Field names and key order match the Paprika JSON schema exactly (verified against sample file).
// Custom encode(to:) enforces both: key order and photo_large:null (Swift's synthesized Codable
// uses encodeIfPresent for optionals, which silently omits nil fields — Paprika crashes on import
// when photo_large is absent rather than null).
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

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(name,            forKey: .name)
        try c.encode(hash,            forKey: .hash)
        try c.encode(directions,      forKey: .directions)
        try c.encode(source_url,      forKey: .source_url)
        try c.encode(description,     forKey: .description)
        try c.encode(photo_hash,      forKey: .photo_hash)
        try c.encode(photo,           forKey: .photo)
        try c.encode(total_time,      forKey: .total_time)
        try c.encode(nutritional_info, forKey: .nutritional_info)
        try c.encode(image_url,       forKey: .image_url)
        try c.encode(servings,        forKey: .servings)
        try c.encode(uid,             forKey: .uid)
        try c.encode(created,         forKey: .created)
        try c.encode(rating,          forKey: .rating)
        try c.encode(prep_time,       forKey: .prep_time)
        try c.encode(categories,      forKey: .categories)
        try c.encode(source,          forKey: .source)
        try c.encode(cook_time,       forKey: .cook_time)
        try c.encode(photo_data,      forKey: .photo_data)
        try c.encode(ingredients,     forKey: .ingredients)
        try c.encode(photos,          forKey: .photos)
        try c.encode(difficulty,      forKey: .difficulty)
        // encode (not encodeIfPresent) writes null for nil — Paprika requires the key present
        try c.encode(photo_large,     forKey: .photo_large)
        try c.encode(notes,           forKey: .notes)
    }
}
