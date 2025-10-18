# Repository Guidelines

## Project Structure & Module Organization
The workspace lives under `Library/`. Swift sources are currently in `Library/Library/` alongside assets and the Xcode app entry point (`LibraryApp.swift`, `ContentView.swift`). Follow the planned breakdown in `README.md` when adding modules: create `Models/`, `Services/`, and `Views/` folders within `Library/Library/` to keep domain models, Supabase integrations, and SwiftUI screens separated. Place shared utilities under `Library/Library/Support/` if you need cross-cutting helpers.

## Build, Test, and Development Commands
Launch the project in Xcode with `open Library/Library.xcodeproj`. For CLI builds run `xcodebuild -scheme Library clean build` from the repo root. Execute the test suite (once available) with `xcodebuild test -scheme Library -destination 'platform=iOS Simulator,name=iPhone 15'`. Use SwiftUI previews for rapid UI iteration; they hook into the same scheme.

## Coding Style & Naming Conventions
Use Swift 5 defaults: 4-space indentation, line length near 100 characters, and trailing commas for multi-line literals. Name Swift types in PascalCase, instances and functions in camelCase, and keep file names aligned with the primary type (`Shelf.swift`, `SupabaseService.swift`, etc.). Prefer extensions for protocol conformance blocks. Run Xcode’s “Editor > Structure > Re-indent” before committing; add `swift-format` if automation becomes necessary.

## Testing Guidelines
Adopt XCTest for unit and integration coverage. Mirror the module tree in `Library/LibraryTests/`, e.g., `Services/SupabaseServiceTests.swift`. Name tests with the pattern `test_<Condition>_<Expectation>()`. Exercise Supabase calls with mocked clients when feasible and reserve live network checks for manual verification. Aim for meaningful coverage on services and data transforms before UI.

## Commit & Pull Request Guidelines
Existing history uses short, imperative, lowercase messages (`add supabase deps`, `initial iOS app`). Continue that voice and focus each commit on a single concern. Pull requests should include a concise summary, a checklist of testing performed, links to related issues, and screenshots or screen recordings for UI changes. Keep diffs focused; open follow-ups rather than bundling unrelated work.

## Supabase Setup Notes
Create `Library/Library/Config.swift` from `Config.example.swift`, populate it with project credentials, and keep it untracked via `.gitignore`. Never commit real keys; instead, document any environment changes in the PR description so teammates can update their local copies.
