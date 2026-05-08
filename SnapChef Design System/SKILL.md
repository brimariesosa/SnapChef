---
name: snapchef-design
description: Use this skill to generate well-branded interfaces and assets for SnapChef, an iOS app that scans your fridge, tracks pantry expirations, and proposes recipes from what you already own. Contains essential design guidelines, colors, type, fonts, assets, and UI kit components for prototyping. The brand voice is smooth, natural, organic, healthy — forest green and cream warmed with sunset accents.
user-invocable: true
---

Read the README.md file within this skill, and explore the other available files.

If creating visual artifacts (slides, mocks, throwaway prototypes, etc), copy assets out of `assets/` and import the tokens from `colors_and_type.css` (or copy the values into a self-contained file). Build with the JSX components in `ui_kits/ios_app/components.jsx` and `screens.jsx` as a starting point — don't recreate them from scratch.

If working on production code (the SwiftUI app), the `assets/` and `colors_and_type.css` values mirror `Theme.swift`. Read the README's Visual Foundations and Iconography sections to become an expert in designing with this brand before making changes.

If the user invokes this skill without any other guidance, ask them what they want to build or design (a marketing page, a new in-app screen, a slide deck, an animated promo, etc.), ask 3–5 questions about audience, surface, and tone, and act as an expert designer who outputs HTML artifacts _or_ production code, depending on the need.

## Quick rules of thumb
- Forest-green primary on cream — never flat white. Use `--grad-bg` + `DecorativeBlobs`.
- CTAs always carry a tinted glow shadow (forest or sunset). A flat CTA looks unfinished.
- Iconography is Phosphor Icons (regular/fill weights only). On iOS native, use SF Symbols. Never emoji.
- Type: Nunito for UI; DM Serif Display only for editorial recipe titles + hero callouts.
- Status colours are reserved (fresh / soon / urgent / expired) — don't repurpose them as decoration.
- Voice is second-person, kitchen-friend warm, short sentences. No "AI-driven," no "robust," no enterprise SaaS energy.
