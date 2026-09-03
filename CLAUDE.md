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

- `QuinsePlannerApp.swift` — `@main` entry point, sets up the single `WindowGroup` scene rendering `ContentView`, and attaches the app's `.modelContainer(for: [...])` (every persisted `@Model` type is registered there).
- `ContentView.swift` — holds most of the app: the shared color palette, the home screen, and every section view still using in-memory state. It is organized with `// MARK:` comments into sections rather than split across files.
- `BudgetView.swift`, `ChecklistView.swift`, `GuestListView.swift` — sections split out into their own files when they moved to SwiftData persistence (see Persistence below). Sections that gain real persistence going forward should move out of `ContentView.swift` the same way rather than growing the monolith further.

Navigation is a single `NavigationStack` declared in `ContentView` (the home screen). The home screen shows a grid of `MenuCard`s (one per app section); each card is a `NavigationLink` that pushes that section's view onto the stack. Sections not yet built out use a shared `ComingSoonView` placeholder so the home screen's cards don't need to change when a section is implemented for real — only its dedicated view (e.g. `VendorsView`) does.

"The Boutique" section is the exception — it's fully built out (not a placeholder), since selling the user's wife's real quinceañera products (dresses, crowns, accessories) is a primary purpose of the app, equal in importance to the planning tools. It's driven by a `Product` model with a `ProductCategory` enum (dress/crown/accessory) and category-filter chips; `BoutiqueView` lists products, `ProductDetailView` shows one, and tapping "Inquire" opens a sheet with placeholder phone/email `Link`s (`tel:`/`mailto:`) that need the boutique's real contact info before shipping. Product photos are SF Symbol icons on colored cards for now, standing in until real photography is added.

## Persistence

Persistence is being introduced section by section — Budget, Checklist, and Guest List are done; the remaining sections (Vendors, Court of Honor) are still in-memory `@State` with no data/model layer beyond simple per-screen structs, and should follow the same pattern below as they're built out for real.

The established pattern, once a section needs real persistence:

- **A collection of user-editable records** (e.g. `BudgetCategory`) becomes a SwiftData `@Model` class, registered on the app's model container in `QuinsePlannerApp.swift` (`.modelContainer(for:)`). The owning view reads it with `@Query` and mutates it through `@Environment(\.modelContext)` — insert for "add", mutate the model instance's properties in place for "edit" (SwiftData models are reference types, so this just works), `modelContext.delete(_:)` for "delete". First-launch sample data is seeded once, in a `.task` on the view, only if the query comes back empty — it's no longer baked into a static in-memory default.
- **A single scalar setting** (e.g. Budget's overall target amount) does *not* need its own SwiftData model just to hold one row — `@AppStorage` (backed by `UserDefaults`) is enough. `Decimal` has no native `AppStorage` support, so it's stored as a `Double` and converted at the view boundary (a computed `Binding<Decimal>`) — see `BudgetView.totalBudgetBinding`.
- **`Color` isn't a SwiftData-storable type.** Where a model needs a color (as `BudgetCategory` does), store a `String` identifier (`colorName`) and map it back to the real `Color` via a computed property / lookup table, rather than trying to persist `Color` directly.
- **A one-to-many relationship between records** (e.g. a category's individual `BudgetExpense`s) uses `@Relationship(deleteRule: .cascade, inverse: \Child.parent)` on the parent's array property — deleting the parent deletes its children with it. A derived total (like a category's spend) is a computed property summing the relationship rather than a separately-maintained stored field, so it can't drift out of sync with the underlying records.
- **Binary data (e.g. a receipt photo)** is stored as `Data?` with `@Attribute(.externalStorage)`, which keeps large blobs out of the main SQLite row. Downscale/re-encode images (see `downscaledJPEGData` in `BudgetView.swift`) before persisting rather than storing picker originals as-is. Photos are picked with `PhotosPicker`/`PhotosPickerItem` (`PhotosUI`), which needs no Info.plist privacy key; camera capture would (there's no physical `Info.plist` in this project — privacy keys go in `project.pbxproj` as `INFOPLIST_KEY_*` build settings).
- Every new `@Model` type must also be added to the container registration in `QuinsePlannerApp.swift` (`.modelContainer(for: [...])`), not just the one a view directly queries.
- **A list with a meaningful order** (e.g. Checklist's planning sequence) needs an explicit stored `sortIndex: Int` and `@Query(sort: \Model.sortIndex)` — sorting by name/title (fine for Budget's free-form categories) would scramble a list that isn't alphabetical to begin with.
- **Built-in copy that must stay localizable** (e.g. `ChecklistItem.title`, unlike user-typed data like a category name or a note) can't be stored as `LocalizedStringKey` — SwiftData can't persist that type. Store it as a plain `String` matching the original literal, then re-wrap it at the display site with `Text(LocalizedStringKey(item.title))` (or `Text(LocalizedStringKey(title))` for a title-only string like a nav title) so it still resolves through the string catalog instead of being displayed as a raw, unlocalized value.
- **An enum-valued field** (e.g. `Guest.rsvpStatus: GuestRSVPStatus`) can be stored directly as a model property as long as the enum is `Codable` (a `String`-raw-value enum gets this for free) — SwiftData persists `Codable` types natively. This is simpler than the `Color`/`colorName` workaround above, which is only needed because `Color` itself isn't `Codable`.
- **Wrapping a system picker with no SwiftUI-native equivalent** (e.g. the Contacts picker for Guest List's "Import from Contacts") means writing a small `UIViewControllerRepresentable` (first one in this project — see `ContactPicker` in `GuestListView.swift`) with a `Coordinator` implementing the relevant `NSObject`-based delegate protocol. As with `PhotosPicker`, presenting the *system picker UI itself* (`CNContactPickerViewController`) needs no Info.plist privacy key — only calling the underlying data store directly (`CNContactStore`, `PHPhotoLibrary`, etc.) would.
- **A section with no sensible generic starter data** (e.g. Guest List — an actual family's guests aren't something to invent placeholder rows for, unlike Budget/Checklist's example categories/tasks) skips `sampleSeed`/`seedIfNeeded` entirely and just renders an empty-state view until the user adds their first record.

This project has no test target yet, so there's no automated coverage of persistence/migration behavior — worth keeping in mind if/when a schema needs to change after real user data exists. It already came up once: moving `BudgetCategory.actualAmount` from a stored property to a derived `totalSpent` (summed from expenses) meant old Simulator installs from before that change needed their app data reset rather than relying on migration to backfill the dropped value into a synthesized expense.

## Localization

The app must support English and Spanish. SwiftUI only auto-localizes `Text`/`.navigationTitle`/`Button`/etc. when given a **string literal** (it resolves to a `LocalizedStringKey` overload) — not a precomputed `String` value. Reusable components that display fixed UI copy (`MenuCard`, `FeaturedCard`, `CategoryChip`) are therefore typed with `LocalizedStringKey` parameters, not `String`, so literals passed in at call sites stay localizable through to display. Keep this pattern for new UI-copy parameters. Actual data (product names/descriptions, phone/email, a checklist item's user-typed note) stays plain `String` — it isn't meant to be looked up in a translation table.

`ChecklistItem.title` is the one exception worth knowing about: it's fixed, built-in copy (like `MenuCard`'s), but since it's a SwiftData `@Model` property it has to be stored as a plain `String` (SwiftData can't persist `LocalizedStringKey`) rather than typed as `LocalizedStringKey` — see the Persistence section for how it's re-wrapped at display time so it still localizes.

Translation infrastructure (a String Catalog resource + Spanish as a project localization) has not been added yet — it requires two Xcode UI steps (Project > Info > Localizations, and File > New > File > String Catalog) rather than direct `project.pbxproj` edits, to avoid corrupting the project file.
