# SnapChef Design System

> **Snap your fridge. Cook what you have. Waste nothing.**

SnapChef is an iOS app that turns a single photo of your fridge into a working pantry — and a working pantry into tonight's dinner. Point the camera, the app's vision model recognises every ingredient, items are tagged with realistic shelf-life estimates, and the recipe screen surfaces dishes you can make *right now* with what you already own. Expiration alerts close the loop so nothing rots in the back of the drawer.

The brand voice is **smooth, natural, organic, healthy** — closer to a farmer's market than a tech app. The visual signature is a forest-green-and-cream palette warmed with sunset accents, soft glassy cards, SF-Rounded typography, and decorative blurred-blob backgrounds. The new mark introduced in this design system blends "Snap" + "Chef" into a wordmark fronted by a leaf-camo monogram.

---

## Sources

- **Codebase:** [github.com/brimariesosa/SnapChef](https://github.com/brimariesosa/SnapChef) (SwiftUI, iOS 17+). The source of truth for tokens, component shapes, and copy. Key files lifted into this system:
  - `SnapChef/Resources/Theme.swift` — color palette, gradients, view modifiers (`primaryButton`, `cardStyle`, `glassCard`, `appBackground`), `DecorativeBlobs`, `PulsingRing`.
  - `SnapChef/Models/Models.swift` — domain types (`PantryItem`, `FoodCategory`, `ExpirationStatus`, `Recipe`).
  - `SnapChef/Views/*.swift` — screen composition, copy, iconography (all SF Symbols).
- **No Figma file** was provided. All visual decisions are derived from the codebase + the existing app icon.
- **Brand brief:** "warm green colour … combination of Snap and Chef as a camo … smooth, natural, organic, healthy."

---

## Index

```
README.md                  ← this file
SKILL.md                   ← Agent Skill manifest (drop this folder into Claude Code)
colors_and_type.css        ← single source of truth for tokens
fonts/                     ← (web fonts loaded via Google Fonts CDN — see fonts note)
assets/
  logo.svg                 ← primary lockup (camo monogram + wordmark)
  logo-mark.svg            ← square mark only
  logo-wordmark.svg        ← wordmark only
  AppIcon-original.png     ← shipped iOS app icon (reference)
  patterns/leaf-camo.svg   ← repeating leaf-camo pattern (background tile)
  illustrations/*.svg      ← scan-ring, fridge, recipe-card hero illustrations
preview/                   ← cards rendered on the Design System tab
ui_kits/
  ios_app/                 ← SnapChef iOS — pixel-faithful HTML/JSX recreation
    README.md
    index.html             ← interactive click-thru: onboarding → snap → pantry → recipes
    components/*.jsx
```

---

## Content fundamentals

**Voice.** SnapChef speaks like a kitchen friend, not an instruction manual. Sentences are short, declarative, and warm. Every screen earns its keep with a verb — "Snap your fridge," "Cook what you have," "Waste nothing." The three-word title-card on the README is the brand cadence in miniature.

**Person.** Second-person ("you," "your"), never first-person ("we," "I"). The app addresses the cook directly: *"Your pantry is empty,"* *"Tap the camera tab to snap your fridge,"* *"Get recipe matches based on your pantry, diet, and kitchen equipment."*

**Casing.** Title Case for screen titles and primary buttons (*"Pantry," "Snap & Scan," "Get Started," "Take Photo," "Add First Item"*). Sentence case for body, helper, and meta copy. ALL CAPS is reserved for tiny meta labels (e.g. uppercase section eyebrows in `t-caption`). Never shout.

**Tone calibration.** Active over passive. Concrete over abstract. Numbers without fanfare ("3 batches", "78% match", "5d left"). Status labels are purpose-built and re-used everywhere — `Fresh`, `Use soon`, `Use now`, `Expired`, `No date`. Empty states are gentle and actionable: *"Your pantry is empty / Tap the camera tab to snap your fridge, or add items manually."*

**Emoji.** None. The codebase uses zero emoji; mood comes from SF Symbol glyphs, soft gradients, and rounded type — not 🥕🥬🍅. Do **not** introduce emoji into new artifacts.

**Vibe words to lean on:** fresh, smooth, natural, organic, healthy, kitchen-warm, hand-on-shoulder. **Vibe words to avoid:** powerful, robust, AI-driven, smart, optimised, "level up." If the copy could appear in an enterprise SaaS dashboard, rewrite it.

**Concrete copy bank** (lifted from the app — re-use verbatim where possible):

| Surface | Copy |
| --- | --- |
| Tagline | Snap your fridge. Cook what you have. Waste nothing. |
| Onboarding 1 | Snap your fridge — Point your camera and let AI identify every ingredient in seconds. |
| Onboarding 2 | Cook what you have — Get recipe matches based on your pantry, diet, and kitchen equipment. |
| Onboarding 3 | Waste nothing — Expiration alerts remind you to use ingredients before they spoil. |
| Snap hero | Point and snap — SnapChef AI identifies every ingredient in seconds. |
| Pantry empty | Your pantry is empty — Tap the camera tab to snap your fridge, or add items manually. |
| Use-soon strip | Use soon · {n} |
| Scan toast | Tap a row to edit. Uncheck anything we got wrong. |
| Duplicate sheet | These items are already in your pantry. Want to add another batch with a fresh expiration date? |
| Primary CTAs | Take Photo · Choose from Library · Get Started · Add First Item · Add {n} |

---

## Visual foundations

**Colour vibe.** Warm and edible. The palette is dominated by **forest green** (`#226940`) on **cream** (`#FCF8F0`), with a **sunset trio** (coral / peach / butter) used sparingly for energy and warning, and a **berry/plum** pair for seasoning, demo and editorial moments. There are no cold blues used as primary chrome — the only blue (`--sky`) is a category tint. Imagery skews **warm, soft, slightly hand-thrown**; never cold, never b&w, never high-contrast tech-noir.

**Backgrounds.** Cream is the floor. Every full-screen surface uses a 3-stop diagonal gradient (`--grad-bg`) plus a `DecorativeBlobs` overlay — three large, heavily-blurred (~80px) circles in peach, mint, and a faint berry, offset off-screen at low opacity. **Never use a flat white background.** Cards sit on top in pure white (`--bone`) so they read as elevated.

**Typography.** The app uses SF Rounded (`design: .rounded`) on iOS. The web substitute is **Nunito** (Google Fonts) — close in proportion, weight range, and friendliness. Display sizes are bold-to-black; body is medium. **DM Serif Display** is reserved for editorial moments (recipe titles, hero callouts). Letter-spacing is tightened for display (`-0.015em` to `-0.02em`) and uppercase-tracked (`0.08em`) for the rare caption.

**Spacing.** 4-pt scale, with a heavy bias toward `16` and `24` for card padding and `12` for tight rows. Cards breathe — `.cardStyle` is `padding: 16` with `radius: 16`.

**Corner radii.** Continuous, generous. Chips are pill-shaped (`--r-pill`). Rows are `14px`. Tiles are `16-18px`. Recipe cards are `20px`. Hero placeholders and sheets push to `24-28px`. **Never use square corners** (radius `0`); the smallest radius in the system is `8px`.

**Borders.** Faint and tinted — never grey. The default border is `rgba(34, 105, 64, 0.18)` (forest at 18% alpha). Borders are `1-1.5px`. They appear on neutral cards and on un-selected chips; selected chips drop the border in favour of a tinted gradient fill.

**Shadows.** Two systems coexist:
1. *Neutral elevation* — warm-black at very low alpha (`0 2px 8px rgba(31,26,18,0.04)` → `0 12px 28px …`). Used on white cards.
2. *Tinted CTA glow* — forest or sunset at 35% (`shadow-cta`, `shadow-sunset`). Reserved for primary buttons and gradient-filled circles. This glow is a SnapChef signature — a CTA without a coloured shadow looks unfinished.

There are **no inner shadows** in the system.

**Glass / blur.** The `glassCard` modifier uses `.ultraThinMaterial` with a 40%-white hairline border. Reach for it for floating sheets and modal cards over imagery, not for everyday surfaces. Backdrop-blur is reserved — it's a treat, not a default.

**Gradients.** Three named gradients carry brand meaning:
- `--grad-primary` (forest → forest-light → mint) = brand, primary CTAs, "fresh" status, scan rings.
- `--grad-sunset` (coral → peach → butter) = warm warning, "use soon," sunset CTAs, hero variants.
- `--grad-berry` (berry → plum) = editorial / demo / "inspired by your photo" highlights.
A new fourth gradient added in this system — `--grad-camo` — is the **leaf-camo wash** used on the brand mark and pattern tiles only.

**Animation.** Spring-led, never linear.
- Page-bounce springs: `cubic-bezier(0.34, 1.56, 0.64, 1)`.
- Repeating breath cycle on hero gradients: 2.5s ease-in-out, autoreverse.
- `PulsingRing` — three concentric stroked circles, scaled `0.85 → 1.25` and faded `1 → 0` over 2.6s, staggered 0.5s. This is the brand's **scanning** motif.
- Page-indicator dots morph from 8px → 24px capsule on selection (spring 0.4 / 0.7).

**Hover / press.**
- *Hover (web only):* surface lifts shadow one step, gradient brightens ~6%. No colour invert.
- *Press:* scale `0.97`, 120ms ease-out. On tinted CTAs, opacity drops to `0.92` for the duration.
- Selected chips swap white-bg → gradient-bg + white-fg in a spring; never colour-flip on hover.

**Transparency / blur.** Used for:
1. Scrim over the camera-scanning overlay (`black / 50%`).
2. The scan-results sheet background (`cream / 40%`) which lets the page tint show through.
3. Glass cards (`ultraThinMaterial`).
Outside these, prefer solid fills.

**Layout rules.**
- Mobile is the canvas: 16px gutters, 12px grid gap.
- Tab bar is fixed at the bottom; everything else scrolls.
- Top nav uses a large title that collapses on scroll (iOS `navigationTitle(.large)`).
- Hero placeholders are `300px` tall with dashed `2px` strokes when "ready"; solid when "captured."
- Decorative blobs sit in a non-interactive layer behind everything.

**Iconography colour vibe.** Icons inside coloured circles are always **white**. Icons inside white cards take on the **category tint** (e.g. produce-mint, dairy-sky). Stand-alone icons in body copy follow the surrounding text colour.

---

## Iconography

SnapChef uses **SF Symbols** end-to-end on iOS. There is no custom icon font, no PNG icon set, no Lucide. For web/HTML artifacts we substitute **[Phosphor Icons](https://phosphoricons.com/)** (loaded via CDN) — its filled+regular pair is the closest free match to SF Symbols' weight/metric system. **Flag this substitution on hand-off so the team can decide whether to ship Phosphor on web or commission an exact set.**

**Substitution table** (the Symbols actually used in the app and their Phosphor equivalents):

| SF Symbol (iOS) | Phosphor (web) | Used for |
| --- | --- | --- |
| `camera.viewfinder` / `camera.fill` | `camera`, `crosshair` | Snap CTA, scan placeholder |
| `fork.knife.circle.fill` / `fork.knife` | `fork-knife` | Recipes, meat category |
| `leaf.fill` | `leaf` | Produce, "fresh", brand mark |
| `cabinet.fill` | `cabinet` | Pantry tab, pantry category, empty state |
| `cup.and.saucer.fill` | `coffee` | Beverages |
| `drop.fill` | `drop` | Dairy |
| `fish.fill` | `fish` | Seafood |
| `square.grid.3x3.fill` | `grid-four` | Grains |
| `sparkles` | `sparkle` | AI scan, demo, magic moments |
| `snowflake` | `snowflake` | Frozen |
| `bag.fill` | `bag` | Other |
| `clock.badge.exclamationmark.fill` | `clock-countdown` | "Use soon" badge |
| `checkmark.seal.fill` / `checkmark.circle.fill` | `seal-check`, `check-circle` | Success / selected |
| `pencil.circle.fill` | `pencil-circle` | Edit row |
| `plus` / `plus.circle.fill` | `plus`, `plus-circle` | Add CTAs |
| `arrow.right` | `arrow-right` | Onboarding next |
| `tray.full.fill` | `tray` | Duplicate-batch sheet |
| `photo.on.rectangle` | `image-square` | Library picker |
| `chevron.right` | `caret-right` | Row affordance |
| `person.fill` / `person.2` | `user`, `users` | Profile, servings |

**Rules.**
- Icons inside gradient-filled circles: white, `1.5x` smaller than the circle, semibold weight.
- Icons inside chip backgrounds: tinted to the chip's colour, regular weight.
- Stand-alone illustrative icons sit in 92×92 → 130×130 gradient-filled circles with a brand-tinted glow shadow.
- **Never draw bespoke SVG icons** in artifacts unless the corresponding Phosphor glyph genuinely doesn't exist. Document any custom icon in this table.

**Emoji and unicode.** Not used. Bullets are `·` (middle dot). Arrows are SF/Phosphor glyphs, not unicode (`→` etc).

**Brand mark.** The new SnapChef logo is a leaf-camo monogram (overlapping S + C) inside a rounded-square frame, paired with a wordmark. See `assets/logo.svg`.

---

## Font substitution flag

> **🔔 Heads-up:** The iOS app uses **SF Pro Rounded** (`design: .rounded`), which is Apple-licensed and not redistributable. Web artifacts in this design system substitute **Nunito** (Google Fonts) as the closest free match. The serif accent uses **DM Serif Display** (Google Fonts) — there is no serif in the iOS app; this is a system-level addition for editorial moments on web/print. **If you have licensed a custom display face for SnapChef (or want to swap to a paid SF Rounded equivalent like SF Pro web fonts), drop the `.woff2` files in `fonts/` and update `colors_and_type.css`.**

---

## Caveats

- No Figma file or marketing site was provided — all derived from the iOS codebase.
- Recipe card photography is shown via SF Symbol glyphs in the app (no real food photos). The UI kit follows suit; brief food photography if rich imagery is needed.
- The "camo" leaf pattern is an original interpretation of the brand brief, not lifted from existing assets.
