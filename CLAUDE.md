# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

**Build & Run:** Open `PaprikAI.xcodeproj` in Xcode and press ⌘R. There is no CLI build — this is an Xcode-only project.

**Tests:** ⌘U in Xcode, or run a single test via the gutter diamond next to an `@Test` function. Tests use Swift Testing (`@Test`, `#expect`) — not XCTest.

**API key (development):** Create a `.env` file in the project root with `OPENAI_API_KEY=sk-...`. In DEBUG builds on Simulator, `APIConfig` reads it automatically at the compile-time source path. Alternatively, set `OPENAI_API_KEY` in the scheme's Run → Environment Variables.

## Architecture

The app has a linear flow: **capture photos → extract via OpenAI Vision → review/edit → export**.

### Key services

**`RecipeExtractionService`** — the only file that calls the network. Sends images to `gpt-4o` with a system prompt and a structured user prompt, receives a `json_object`, and maps it into `ExtractedRecipe`. Both prompts live as computed vars in this file — this is where to make changes for accuracy or field handling.

**`PaprikaExportService`** — two export paths:
- `exportYAML` → `.yml` file (human-readable, for debugging/sharing)
- `exportPaprika` → `.paprikarecipes` file (ZIP of gzip-compressed JSON)

The ZIP uses *stored* (no compression) entries because the inner `.paprikarecipe` files are already gzip-compressed. The gzip implementation converts `NSData.compressed(.zlib)` output from zlib RFC 1950 format to gzip by stripping the 2-byte CMF/FLG header and 4-byte Adler-32 trailer and prepending a 10-byte gzip header.

**`RecipeStore`** — persists recipe history to `UserDefaults` via JSON-encoded `[ExtractedRecipe]`.

### Models

**`ExtractedRecipe`** — the app-side model. All views and services operate on this type.

**`PaprikaRecipe`** — the exact Paprika JSON schema. Has a custom `encode(to:)` that enforces key order and encodes `photo_large` as `null` (not omitted) — Paprika crashes on import if this key is absent.

### Ingredient section headers

Ingredients with named sections (e.g. "Salad", "Dressing") are stored in `ExtractedRecipe.ingredients` with a `!` prefix (`"!Salad"`). `PaprikaExportService` strips the `!` and appends `:` when building export output. The extraction prompt instructs the model to use this convention.

### View hierarchy

`MainRecipeListView` (list) → `NewRecipeFlowView` (orchestrates the flow) → `PhotoReviewView` (capture/select photos) → `RecipeReviewView` (editable form) → share sheet for export. `RecipeDetailView` handles tapping a past recipe from the list.
