# Papyrus

Papyrus is a SwiftUI + SwiftData app for tracking coffee beans, brew recipes, and individual brews. It focuses on modern iOS design, supports iOS 17+, and emphasizes pour-over workflows (dose, water temp, brew curve) while keeping inventory and tasting feedback in sync.

## Features

- **Bean Management**
  - Store roaster, origin, roast level/date, bag weight, and remaining grams (grams-only UI).
  - Inventory ring previews update automatically when brews deduct beans.
  - Quick edit sheet consolidates roaster/origin/roast metadata editing.
- **Recipe Builder**
  - Structured parameters (dose, ratio, yield, temperature, grind, brew time).
  - Live pour timeline preview rendered with `Charts`.
  - Dedicated pour-step editor with timeline-at-top layout, compact steppers, numeric popovers, and per-step notes.
  - Read-only timeline in recipe detail view plus metadata tiles.
- **Brew Logging**
  - New brew flow captures bean, recipe, pour steps, ratings (Acidity / Balance / Sweetness), notes, and tasting notes.
  - Beans and recipes can be selected from SwiftData or entered as “Other …” with custom names. Custom beans skip inventory deduction; custom recipes start from a blank pour timeline.
  - Editing pour steps for a brew reuses the same timeline editor used by recipes.
  - Brew detail screen mirrors the recipe layout with overview, pour timeline, ratings, notes, and tasting notes.
  - Timeline graph uses the shared component so columns stay visually consistent.
- **Instances/Brews Tab**
  - Renamed to “Brew” with cup icon; list view shows bean name (or custom label), snapshot name, mini ratings pills, and tasting notes preview.

## Architecture

- **SwiftUI** for all UI, `NavigationStack` & `Form` for flows.
- **SwiftData** models: `Bean`, `Recipe`, `PourStep`, `BrewLog`, `BrewStepSnapshot`.
- Shared pour-step editing toolkit (`PourStepEditing.swift`) provides:
  - `StepDraft` model, `PourStepDraftContainer` protocol.
  - `PourStepsEditorView` with timeline header and newest-first ordering.
  - `StepEditorRow`, `NumericPopoverView`, `CompactStepper`, etc.
- Shared `PourTimelineChart` renders any sequence of pour steps.

## Development Notes

### Requirements

- Xcode 15.4+ (iOS 17 SDK, Swift 5.9+).
- iOS 17+ targets (designed around iPhone 16-sized preview).

### Building

```bash
xcodebuild -project Papyrus.xcodeproj -scheme Papyrus -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build
```

> **Note:** SwiftData cannot migrate stores automatically. If the model schema changes (e.g., new properties on `BrewLog`), uninstall the previous build or delete the simulator container before launching the new version.

### Project Layout

```
Papyrus/
├── BeansListView.swift
├── BrewListView.swift
├── ContentView.swift
├── PapyrusApp.swift
├── PourStepEditing.swift
├── PourTimelineChart.swift
├── Recipe.swift
├── RecipesListView.swift
└── SwiftData models & assets
```

### SwiftData Schema

- `Bean`: roaster/origin/roast metadata, grams tracking, flavor notes.
- `Recipe`: dose, water temp, grind, brew duration, pour steps.
- `PourStep`: start time, duration, water amount, notes, linked to recipe.
- `BrewLog`: snapshot info, ratings, tasting notes, optional bean/recipe, custom bean name, pour-step snapshots.
- `BrewStepSnapshot`: stored pour steps for a brewed instance.

## Contributing

1. Create feature branch.
2. Run `xcodebuild` (or build/run via Xcode) to ensure no regressions.
3. Include SwiftData schema migrations (or document store-reset instructions) if you add/remove properties.

## License

MIT (if unspecified, adjust accordingly).
