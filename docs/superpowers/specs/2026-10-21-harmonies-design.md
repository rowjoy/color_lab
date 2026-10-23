# Harmonies and saved palettes design

The user's “Next” continues the established module workflow with Phase2 Harmonies: six modes, a wheel and swatches opening common details, plus durable whole-palette saving. This is a small new subsystem with a written design/plan; the original instruction to follow the document and start without unnecessary questions preserves continuous implementation. Color games/vision tests and room-photo work remain later modules.

## Experience

Lab gains Open harmonies without replacing HSL, Mixer or Formula. Common details gains Explore harmonies for the exact currently selected color. A guarded `/harmonies` route retains a session base/mode, defaults to Lilac and Complementary, and offers the existing manual-HEX/saved-color picker. Six wrapping mode chips generate a premium code-drawn HSL relationship wheel and tappable swatch rows. The wheel is a labeled diagram, not a pretend interactive control; swatches are the accessible48dp actions. It depicts hue, not measured pigment/paint compatibility.

Rotational modes preserve saturation/lightness and use complementary+180, analogous−30/+30, triadic+120/+240, tetradic+90/+180/+270, split-complementary+150/+210. Anchor comes first and remains the exact input RGB. Monochromatic keeps hue/saturation and uses anchor plus L offsets−.30,−.15,+.15,+.30 clamped to0..1. RGB duplicates collapse preserving order; neutrals have no hue, so rotational modes honestly return one shade. Neutral monochromatic shades vary lightness. Explain this when applicable rather than fabricate distinct colors or hue angles.

Save palette asks for a name and stores the exact ordered colors, base, mode and creation time. A repeat save of the same base/mode preserves one existing snapshot/name/date (the UI identifies it as already saved). A pending save captures its original draft, never re-labels a later edit as saved; failures remain retryable without discarding the draft. Palette tab gains Palettes alongside existing Saved/Studio. `/palettes` exposes the same collection from a View saved palettes action. Cards show the persisted snapshot and tappable colors, open its base/mode in the editor, and confirm before deletion. Opening/editing a palette does not mutate its saved snapshot; deletion does not delete individual saved colors. Search/favorites for individual colors remain untouched.

Common details closes before entering harmonies, sets exact base without resetting the selected mode, and awaits the nested route so the camera caller retains pause/resume ownership. Already on `/harmonies`, update the base without stacking another route. Formula, Room, share, harmony replacement, startup guards and camera lifecycle must remain intact. Since detail actions now exceed two distinct destinations, use a private enum rather than adding more ambiguous boolean combinations, limited to this touched flow.

## Data and persistence

Pure core owns HarmonyMode/generation. A small non-autoDispose Riverpod notifier owns session base/mode. Wheel rendering is a separate stateless presentation unit, with diagram semantics including actual HEX shades and neutral explanation.

SavedPalette is immutable and validates trimmed nonblank name, UTC time, canonical identity and1..5 distinct RGB colors with the base first. Identity is `${mode.name}-${base.hex.substring(1)}`. Store the ordered snapshot, not just an instruction to regenerate later. A separate version1 Hive `color_palettes_v1` box in the existing app-private color_lab directory avoids touching color history/preferences schemas. Unknown versions, malformed records and corrupt storage are preserved and reported, never cleared/recovered by truncation. Operations serialize including reads and close; writes resolve after flush, with a failed-flush barrier even for duplicate/no-op operations. A failed close can be retried.

Repository/controller lifetime and failure behavior follow the established durable-history pattern without refactoring working repositories. Its directory provider is independent so a palette retry cannot needlessly reset other libraries. No new packages, native permissions or backend. Only explicit confirmed deletion removes a selected stored palette.

## Choices and boundaries

Chosen: deterministic standard HSL rotations, a read-only procedural diagram plus real swatch controls, and a separate durable collection. A draggable wheel/base HSL editor would duplicate existing HSL/picker tools; JSON-only export would not meet local palette persistence. Do not add palette sharing/renaming/projects, save-all-photo palettes or games in this module. Names are user-entered (English-only requirement applies to app chrome, not user text).

## Verification

Test-first fixtures pin all six modes, wraparound, exact anchor, deduplication, neutral/black/white and mono lightness/clamping. Persistence tests use actual files/reopens and injected flush/open/corruption failures, isolation, idempotent saves, serialized updates and retry/disposal. Wheel tests cover semantic content, rendering/theme/text scale and neutral handling without misleading tap claims. Integration tests cover selection/cancel/retained drafts, exact details entry/nonstacking, all-mode output, named save/duplicate/failure/draft change during pending write, library load/retry/open/delete/cancel, fresh-container disk restart, guards, correct shade details/Room and camera→details→harmonies→Back with no hidden stream restart. Both themes360px/2x/reduced motion, real-font previews, full suite/analyzer/format/APK and independent task/final review precede a validated cumulative source ZIP.
