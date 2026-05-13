# SnapChef — project instructions

> **Snap your fridge. Cook what you have. Waste nothing.**

SnapChef is an iOS app (SwiftUI, iOS 17+, SwiftData) that scans the
contents of a fridge from a single photo, builds a pantry with
expiration tracking, and suggests recipes that match what's on hand.
Vision + recipe sourcing both run through Anthropic's Claude API. The
codebase lives in this directory; the canonical brand and visual system
lives in `SnapChef Design System/`.

This file is the always-on project context. Read the **Design system**
section before changing any UI, the **Architecture** section before
changing data flow, and the **House rules** section before opening a PR.

---

## Design system — non-negotiable

The brand and UI system for SnapChef is fully documented in
**`SnapChef Design System/`** at the root of this repo. **Treat it as
the source of truth for every visual decision** — colors, typography,
gradients, shadows, spacing, radii, copy voice, iconography. Anything
new added to the app must conform to it; anything currently in the app
that drifts from it should be brought back in line.

Where to look first:

- **`SnapChef Design System/README.md`** — the full design system spec.
  Voice, copy bank, color tokens, gradients, typography, shadows,
  spacing, animation, layout rules, iconography substitution table,
  component shapes. Re-read the **Visual foundations** and **Iconography**
  sections before any UI work.
- **`SnapChef Design System/colors_and_type.css`** — single source of
  truth for tokens. Mirrors `SnapChef/Resources/Theme.swift`.
- **`SnapChef Design System/SKILL.md`** — agent skill manifest. The
  short version of the design rules.
- **`SnapChef Design System/assets/`** — logo, brand mark, leaf-camo
  pattern, illustrations.
- **`SnapChef Design System/ui_kits/ios_app/`** — pixel-faithful
  HTML/JSX recreation of every iOS screen for prototyping.

### Hard rules — apply everywhere

These come from the design system and are repeated here so they're
unavoidable:

1. **Forest-green primary on cream — never flat white.** Full-screen
   surfaces use `Theme.appBackgroundGradient` plus `DecorativeBlobs`.
   Cards sit on top in pure white (`--bone`).
2. **CTAs always carry a tinted glow shadow** (forest for primary,
   sunset for warning). A flat CTA looks unfinished. Use the
   `primaryButton` modifier in `Theme.swift`.
3. **Type is SF Rounded** on iOS (`design: .rounded`). Display sizes
   are bold-to-black; body is medium. Never use the system default font
   for body or display copy.
4. **Iconography is SF Symbols only** on iOS — never emoji, never
   custom SVG. Web/marketing artifacts substitute Phosphor Icons; the
   substitution table is in the design system README.
5. **Status colors are reserved** — `fresh` / `soon` / `urgent` /
   `expired` / `unknown` map to specific palette slots. Don't
   repurpose them as decoration. See `ExpirationStatus` in
   `SnapChef/Models/Models.swift`.
6. **Corner radii are continuous and generous.** Chips are pill,
   rows 14px, tiles 16-18px, cards 20px, sheets 24-28px. Never radius 0.
7. **Borders are forest at 18% alpha**, not grey. Default is
   `Theme.forestGreen.opacity(0.18)`.
8. **Three brand gradients carry meaning:**
   - `Theme.primaryGradient` (forest → mint) = brand, primary CTAs,
     "fresh" status, scan rings.
   - `Theme.sunsetGradient` (coral → peach → butter) = warm warning,
     "use soon," sunset CTAs.
   - `Theme.berryGradient` (berry → plum) = editorial / demo /
     "inspired by your photo" highlights.
9. **No emoji anywhere.** Bullets are `·` (middle dot). Mood comes
   from SF Symbols, soft gradients, and rounded type.
10. **Animation is spring-led, never linear.** `PulsingRing` is the
    scanning motif; reuse it for any vision-in-progress moment.
11. **Glass / blur is a treat, not a default.** Reach for
    `.ultraThinMaterial` only on floating sheets and modal cards over
    imagery.
12. **Backgrounds always layer:** gradient + `DecorativeBlobs`. Never
    a flat color underneath app chrome.

### Voice — non-negotiable

- **Second-person.** "Your pantry is empty," not "The pantry is empty."
- **Short, declarative, warm.** Sentences earn their keep with a verb.
- **Title Case** for screen titles and primary buttons. Sentence case
  for body, helper, and meta. ALL CAPS only for the rare uppercase
  caption eyebrow.
- **Numbers without fanfare** — "3 batches," "78% match," "5d left."
- **Vibe words to lean on:** fresh, smooth, natural, organic, healthy,
  kitchen-warm.
- **Vibe words to avoid:** AI-driven, smart, robust, optimised, level
  up, powerful. If it sounds like enterprise SaaS, rewrite it.
- **Reuse the copy bank** in the design system README verbatim where
  the surface matches.

### Workflow when adding or changing UI

1. Open `SnapChef Design System/README.md` and locate the relevant
   section (Visual foundations / Iconography / Voice).
2. Look in `SnapChef/Resources/Theme.swift` for an existing token,
   gradient, or modifier. Reuse before introducing.
3. If a new token is genuinely needed, add it to **both**
   `Theme.swift` and `SnapChef Design System/colors_and_type.css`
   so the two stay in sync.
4. For new copy, draft 2-3 variants in the brand voice and pick the
   shortest one that still earns its verb.

---

## Architecture

**Stack.** SwiftUI, SwiftData, iOS 17+, Anthropic API for vision and
recipe sourcing. No third-party dependencies.

**Layout.**

- `SnapChef/SnapChefApp.swift` — entry point, SwiftData container,
  `AppState`. Schema list lives here — register every new `@Model`.
- `SnapChef/Models/Models.swift` — all SwiftData models and the
  `Recipe` value type. Keep the schema flat; one file is fine.
- `SnapChef/Resources/Theme.swift` — all tokens, gradients, view
  modifiers (`primaryButton`, `cardStyle`, `glassCard`, `appBackground`),
  `DecorativeBlobs`, `PulsingRing`. **Mirror changes into the
  design system CSS.**
- `SnapChef/Services/` — single-purpose services, each a `final class`
  with a `static let shared`. New services join the
  `Services` Xcode group; remember to register them in
  `SnapChef.xcodeproj/project.pbxproj`.
- `SnapChef/Views/` — one screen per file. Composition first,
  state second, helpers last.

**Persistence.** Everything user-owned is SwiftData
(`PantryItem`, `PantryBatch`, `DietaryProfile`, `KitchenEquipment`,
`AppNotification`, `CachedRecipe`). In-memory types (`Recipe`,
`DetectedIngredient`) are plain structs. SwiftData migrations are
implicit — when adding fields, default them so existing stores keep
working.

**Recipes.** Generated directly by Claude (Sonnet) from the user's
pantry + dietary profile + available kitchen equipment via
`ClaudeAPIClient.generateRecipes(...)`. No web search, no scraping
(allrecipes.com blocks crawlers). The Recipes tab calls it on first
appear and on the "Fresh Ideas From Your Pantry" CTA; the post-scan
sheet calls it with `detectedIngredients` biasing toward the photo.
Each fresh generation replaces the previous batch in `CachedRecipe`
so the cache always reflects the user's current pantry. Hardcoded
`sampleRecipes` in `MockDataService.swift` is the offline fallback —
keep it small and don't expand it as a primary source.

**Notifications.** Expiration alerts schedule at 3 / 2 / 1 / 0 days
before expiry per batch (see `NotificationService.scheduleExpirationAlert`).
The in-app bell in the Pantry toolbar reads from `[AppNotification]`
synced by `InAppNotificationSync.sync(...)`.

**Vision.** `ClaudeAPIClient.analyze(image:)` posts the photo to
Claude with a JSON-only response prompt. Claude returns detected
ingredients + their printed expiration date when visible on packaging;
when no date is visible, the field stays nil and the user enters one
manually from `ItemDetailView`.

---

## House rules

- **Build for iPhone 16 simulator before declaring anything done:**
  `xcodebuild -project SnapChef.xcodeproj -scheme SnapChef -destination 'id=2E5EDE07-4B43-4C74-AF50-80C300FA4A9C' build`
  (or whatever sim is current — `xcrun simctl list devices available`).
  A green build is the minimum bar; UI claims still need a screenshot
  or runtime verification.
- **Always git push after a task** (per the user's standing rule in
  the auto-memory).
- **English only** in source files and chat output, even when the
  user writes in Polish.
- **Don't add files outside the Xcode project.** When you create a
  new `.swift`, immediately register it in `project.pbxproj` (build
  file ref + file ref + group entry + Sources build phase). The
  pattern is consistent — copy any existing entry like
  `AllRecipesService.swift`.
- **Don't expand `MockDataService.sampleRecipes`** as a primary
  source. It exists only as the offline fallback for
  `AllRecipesService`.
- **Don't introduce a third-party package** without checking with
  the user first. The brand promise is "smooth, natural, organic" —
  the codebase honours that with zero external dependencies.
- **Don't fork the design tokens.** If you change a color, gradient,
  shadow, or radius in `Theme.swift`, mirror the change in
  `SnapChef Design System/colors_and_type.css` in the same commit.
- **Comments are rare.** Only when the *why* is non-obvious. Code
  is the primary documentation.

---

## When in doubt

If the design system and the existing code disagree, **the design
system wins**. The codebase predates the system in many places and
will be brought into line over time. Surface drift when you spot it —
fix it in-place if the change is small, or flag it for the user if
it'd be a larger refactor.
