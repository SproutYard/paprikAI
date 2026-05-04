# PaprikAI

An iOS app that turns photos of printed or handwritten recipes into Paprika-compatible export files.

## What it does

1. **Photograph** — take one or more photos of a recipe (camera or photo library)
2. **Extract** — sends images to OpenAI Vision, which returns structured recipe data
3. **Review** — edit the extracted name, ingredients, directions, times, etc.
4. **Export** — generates a `.paprikarecipes` file and presents the iOS share sheet

The exported file opens directly in Paprika 3 on iPhone, iPad, or Mac.

## File format

`.paprikarecipes` files are ZIP archives. Each recipe inside is a gzip-compressed JSON file (`<Name>.paprikarecipe`). The format was reverse-engineered from a real Paprika export file included in the project root.

## Setup

### API key

The app calls OpenAI's `gpt-4o` model. Set your key before running:

1. In Xcode, open **Product → Scheme → Edit Scheme**
2. Go to **Run → Environment Variables**
3. Add `OPENAI_API_KEY` = `sk-...`

For release builds, swap in a backend proxy — see the `TODO` comments in `APIConfig.swift`.

### Xcode

- iOS 26.2+, Swift 5
- No external dependencies — gzip and ZIP are implemented in pure Swift
- Open `PaprikAI.xcodeproj` and run

## Project structure

```
PaprikAI/
├── Models/
│   ├── ExtractedRecipe.swift      # App-side recipe model
│   └── PaprikaRecipe.swift        # Paprika JSON schema
├── APIConfig.swift                # API key loading
├── RecipeStore.swift              # Persistent recipe history (UserDefaults)
├── RecipeExtractionService.swift  # OpenAI Vision API call
├── PaprikaExportService.swift     # gzip + ZIP export, CRC32, UIImage resize
├── CameraPicker.swift             # UIImagePickerController wrapper
├── MainRecipeListView.swift       # Recipe history list
├── PhotoReviewView.swift          # Multi-photo capture/selection
├── RecipeReviewView.swift         # Editable recipe form
├── NewRecipeFlowView.swift        # Full capture → process → review flow
└── PaprikAIApp.swift              # App entry point
```
