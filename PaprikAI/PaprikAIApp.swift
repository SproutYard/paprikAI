import SwiftUI

@main
struct PaprikAIApp: App {
    @State private var store = RecipeStore()

    var body: some Scene {
        WindowGroup {
            MainRecipeListView()
                .environment(store)
        }
    }
}
