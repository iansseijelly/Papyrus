# Papyrus Agent Notes

These notes capture project-specific context so future Codex agents can work efficiently without relearning the app’s conventions each time.

## Architectural Overview
- **Frameworks:** SwiftUI + SwiftData (iOS 17+). No UIKit/AppKit shims.
- **Model Schema:** `Bean`, `Recipe`, `PourStep`, `BrewLog`, `BrewStepSnapshot`. Schema changes require deleting the existing SwiftData store (uninstall app / reset simulator) before running new builds.
- **Shared Components:**
  - `PourTimelineChart.swift` – renders cumulative pour curves for recipes/brews.
  - `PourStepEditing.swift` – contains `StepDraft`, `PourStepDraftContainer`, `PourStepsEditorView`, `StepEditorRow`, numeric popovers, compact steppers, etc. Both recipes and brews conform to the container protocol; prefer reusing/editing this toolkit instead of reimplementing pour-step logic elsewhere.

## UI Conventions
- **Navigation:** `NavigationStack` and `Form` for data entry flows; detail screens use `ScrollView` + card-style sections.
- **Buttons/Lists:** Selection rows (beans/recipes) use full-width `Button` with `.buttonStyle(.plain)` plus `.contentShape(Rectangle())` so the entire row is tappable. Follow this approach for any new selection list to keep spacing consistent.
- **Inline Inputs:** Use the `inlineTextField` helper (LabeledContent + trailing text field) for right-aligned inputs (snapshot name, method, grind, custom bean name). Avoid ad-hoc styling.
- **Rating Pills:** Use the shared `ratingPill(label:fullLabel:value:)`—even abbreviated “A/B/S” pills include accessibility labels for full attribute names.
- **Timeline Editor:** The pour-step editor is a sheet with a fixed timeline header (safe-area inset) and a list of steps ordered newest→oldest. When adding step-related features, modify `PourStepsEditorView` so recipes and brews stay in sync.

## Data Entry Rules
- **Pour Steps:** Every recipe/brew must have at least one pour step; the save button is disabled otherwise. Steps are stored in grams + seconds only—no ounces or Fahrenheit anywhere.
- **Custom Beans/Recipes:** “Use Other …” options allow brews without linking to SwiftData objects. For custom beans, `customBeanName` must be non-empty (default “Other Bean”); pour steps must still be defined manually. When custom bean is selected, skip inventory deduction. When custom recipe is selected, don’t auto-copy from templates.
- **Modified Toggle:** The “Mark as modified” toggle defaults off and auto-enables the first time brew settings/pour steps differ from the base recipe. Don’t auto-disable it. Final snapshot name appends “-modified” only when the toggle is on.
- **Inventory:** Inventory deductions happen only when a `Bean` entity is linked. Future edits that consume beans should continue to respect `usesCustomBean`.

## Styling Reminders
- Keep typography consistent with SF font weights already in use (`.headline`, `.caption`, `.caption2`). Avoid mixing custom fonts.
- Pills, cards, and text fields use system colors (`Color(.secondarySystemFill)`, `.regularMaterial`). Don’t introduce bespoke color constants unless part of a designed theme.
- Grams-only UI: ensure new features report weights in grams via `formatGrams(_:)`.

## Build & Debug Tips
- SwiftData cannot migrate automatically; schema changes mean you must uninstall the existing app/simulator build before running. Mention this to users if they hit container errors.
- When tests/builds fail inside Codex due to sandboxed DerivedData paths (`Operation not permitted`), inform the user to rerun `xcodebuild -project Papyrus.xcodeproj -scheme Papyrus -configuration Debug -destination 'generic/platform=iOS' build` locally.
- `PourStepEditing` depends on `formatDuration` semantics; if you change formatting, update the helper inside `PourStepEditing.swift` to keep both recipe/brew editors consistent.

## Suggested Workflow
1. Run `xcodebuild …` locally (outside Codex) to verify changes. Codex can’t always write to DerivedData.
2. After schema edits, remind the user to delete the app/simulator to rebuild the store.
3. Reuse the shared components; avoid copy/paste of pour-step or timeline logic.

Document noteworthy changes or quirks here for future agents.***
