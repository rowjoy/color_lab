# Task3 UI review brief

Code-scoped part of Task3 from2026-10-21-color-mixer.md. Delivery/build/archives are verified separately by root and the final reviewer.

## Global constraints

- App UI English only, offline/on-device, Android minimum SDK24 and iOS-ready.
- LAB is the default: weighted arithmetic mean of D65 L*,a*,b*, then display RGB conversion. RGB means weighted arithmetic mean of encoded sRGB display channels, round once at output; label it honestly as digital blending, not paint chemistry.
- UI starts with Lilac#B2A4D4/Butter#E8DAA9 at50 parts each; each ingredient weight is finite0–100. Keep at least two ingredients; no arbitrary maximum. All-zero weights show no result and cannot be saved.
- Existing tokens/shared controls,48dp targets,360px/2x text, both themes/readable text contrast and reduced motion. No automatic permission calls, new packages, history schema/source changes, or unrelated refactoring.
- No Git repository exists: use current authorized folder, preserve old source ZIPs and user/device data. User's module-by-module “next” authorizes this scoped implementation without another approval gate.

## UI requirements

- `/mixer` outside the tab shell under existing onboarding/startup guards, entered from Lab. Preserve HSL study and draft on navigation. Use existing pure math/state APIs rather than duplicate calculations.
- Live selected result, LAB/RGB mode and both actual comparisons, contribution bar filtering zero weights, stable ingredient IDs, relative sliders, minimum-two removal and uncapped additions. Allzero shows recovery without fabricated values/save/details.
- Main selected result opens common details and saves with ColorSource.lab, using exactly the selected mode output. Pinned swatch/HEX stays visible while scrolling through ingredients, opens exact selected result, and hides for allzero.
- Return-only color picker uses root modal, validated manual HEX and actual saved library with local search, no global Palette filter mutation. Loading/failure/retry cannot block manual entry. Cancel/dispose/stale callbacks cannot mutate the wrong ingredient. Confirm Reset before restoring defaults.
- Tests exercise manual/library selection, invalid inputs/cancel/error/long-list selection, actual ratios and modes, live slider drag while scrolled, zero-total suppression/recovery, min2/reset confirm, selected save/details source, guarded routing and HSL/session retention, narrow2x/reducedmotion/both themes.
- Reuse shared visual controls and tokens. No native capture, recipe persistence, new dependencies or unrelated feature expansion.

## Files

lib/features/mixer/presentation/{mixer_screen,mixer_color_picker}.dart; Lab entry; app_router mixer registration; corresponding two presentation test files. Existing math/controller contracts were separately reviewed and approved.
