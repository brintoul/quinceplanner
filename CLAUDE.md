# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

QuinsePlanner is an iOS app to help people plan a quinceañera party (guest list, budget, vendors, court of honor, timeline/checklist, etc.), built with SwiftUI (Xcode project, no SPM/CocoaPods dependencies), with a single `QuinsePlanner` app target and no test target yet. The visual style is intentionally colorful/image-rich (pink/magenta/gold theme, gradients, SF Symbols in colored badges) rather than plain system-default UI.

- Bundle ID: `com.liliscreations.QuinsePlanner`
- Deployment target: iOS 26.5
- Swift version: 5.0
- Device family: iPhone + iPad (`TARGETED_DEVICE_FAMILY = 1,2`)

## Commands

Build and run from Xcode (`QuinsePlanner.xcodeproj`) normally. From the command line:

```bash
# List available simulators/destinations
xcodebuild -project QuinsePlanner.xcodeproj -scheme QuinsePlanner -showdestinations

# Build for a simulator
xcodebuild -project QuinsePlanner.xcodeproj -scheme QuinsePlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Note: no `.xcscheme` is currently checked into the repo (only user-local scheme state exists), so `xcodebuild` may need `-scheme QuinsePlanner` to resolve automatically on first run, or a shared scheme may need to be created in Xcode (Product > Scheme > Manage Schemes > check "Shared") before CLI builds work reliably.

There is no test target yet — `xcodebuild test` has nothing to run until one is added.

## Architecture

- `QuinsePlannerApp.swift` — `@main` entry point, sets up the single `WindowGroup` scene rendering `ContentView`.
- `ContentView.swift` — currently holds the entire app: the shared color palette, the home screen, and every section view. It is organized with `// MARK:` comments into sections rather than split across files.

Navigation is a single `NavigationStack` declared in `ContentView` (the home screen). The home screen shows a grid of `MenuCard`s (one per app section); each card is a `NavigationLink` that pushes that section's view onto the stack. Sections not yet built out use a shared `ComingSoonView` placeholder so the home screen's cards don't need to change when a section is implemented for real — only its dedicated view (e.g. `GuestListView`) does.

"The Boutique" section is the exception — it's fully built out (not a placeholder), since selling the user's wife's real quinceañera products (dresses, crowns, accessories) is a primary purpose of the app, equal in importance to the planning tools. It's driven by a `Product` model with a `ProductCategory` enum (dress/crown/accessory) and category-filter chips; `BoutiqueView` lists products, `ProductDetailView` shows one, and tapping "Inquire" opens a sheet with placeholder phone/email `Link`s (`tel:`/`mailto:`) that need the boutique's real contact info before shipping. Product photos are SF Symbol icons on colored cards for now, standing in until real photography is added.

There is no persistence yet (all state is in-memory `@State`) and no data/model layer beyond simple per-screen structs (e.g. `ChecklistItem`). As the app grows, this file should be updated to describe the real state-management/persistence approach once one is established, and to note if/when views get split into separate files.

## Localization

The app must support English and Spanish. SwiftUI only auto-localizes `Text`/`.navigationTitle`/`Button`/etc. when given a **string literal** (it resolves to a `LocalizedStringKey` overload) — not a precomputed `String` value. Reusable components that display fixed UI copy (`MenuCard`, `FeaturedCard`, `CategoryChip`, `ChecklistItem.title`) are therefore typed with `LocalizedStringKey` parameters, not `String`, so literals passed in at call sites stay localizable through to display. Keep this pattern for new UI-copy parameters. Actual data (product names/descriptions, phone/email) stays plain `String` — it isn't meant to be looked up in a translation table.

Translation infrastructure (a String Catalog resource + Spanish as a project localization) has not been added yet — it requires two Xcode UI steps (Project > Info > Localizations, and File > New > File > String Catalog) rather than direct `project.pbxproj` edits, to avoid corrupting the project file.
