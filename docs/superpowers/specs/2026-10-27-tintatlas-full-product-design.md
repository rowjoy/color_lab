# TintAtlas Full Product Design and Master Task Checklist

**Status:** Approved for implementation planning

**Date:** 2026-10-27

**Branch:** TintAtlas

**Product title:** TintAtlas: Room Visualizer

**Implementation state:** No product code is authorized by this document until the user approves it and a separate implementation plan is written.

## 1. Intent

TintAtlas is a worldwide, all-free, privacy-conscious color product with three connected pillars:

1. **Room Visualizer** helps people preview and compare colors in illustrated rooms and their own room photos.
2. **Color Learning** helps students, artists, designers, and curious users understand color through guided experiments.
3. **Color Games** provide offline practice and casual retention without blocking core tools.

The store-facing promise remains room-first because “Room Visualizer” is the clearest high-intent search proposition. Learning builds trust and repeat value. Games provide optional engagement without taking over the app.

The app remains brand-neutral. It will not ship Asian Paints or another paint manufacturer’s proprietary shade catalogue, branding, product claims, or copied editorial content.

## 2. User decisions already captured

- App/store title: **TintAtlas: Room Visualizer**.
- Worldwide target rather than one paint market.
- Core functionality is free.
- Monetization is Google AdMob banner-only and implemented last.
- No forced ad click, ad unlock, interstitial, rewarded, app-open, or gameplay interruption.
- Existing Bubble Shooter, Fruit & Veggie Pop, Water Sort, Rainbow Rings, and Color Match games remain.
- Add smarter AI-assisted room-mask correction.
- Improve Illustrated Rooms.
- Reframe Color Lab for people studying color.
- Add an original coloring experience inspired by the broad color-by-number interaction, not by copied artwork, characters, screens, or wording.
- Bundle original, brand-neutral starter room palettes instead of Asian Paints shade names, codes, imagery, or copied article content.
- Work remains on the existing TintAtlas branch.
- The current user-owned modification in lib/main.dart must be preserved.

## 3. Recommended product calls included in this draft

Approval of this design accepts these calls unless the user corrects one:

- Root destinations: **Home, Rooms, Learn, Games**.
- “My Work” is reachable from Home and relevant feature screens rather than becoming a fifth compact-phone tab.
- Launch positioning: Room Visualizer first; Learning second; Games third.
- Proposed Android package/application ID: **com.roomvisualizer.tintatlas**.
- English is the first complete locale; all new copy is externalized and layouts are localization/RTL-ready.
- Proposed audience: **13+ general audience, not specifically child-directed**. Store presentation must match that declaration; cute coloring content alone must not be marketed as a preschool/kids product.
- Android receives the first controlled beta because the current project is Android-first. iOS reaches public release only after functional parity and real-device verification.
- Release gates apply per platform: Android may reach public v1 after all shared and Android-specific gates pass; unfinished iOS work does not block Android. iOS cannot publish until the same shared behavior plus every iOS-specific archive/device/store gate passes.
- Supported launch form factors are Android/iOS phones and tablets, portrait and landscape. Desktop and web are not launch commitments.
- Provisional OS floors preserve the current project settings: Android API 24 and iOS 13. A measured dependency/model/device review may recommend raising either floor, but implementation must not silently reduce support.
- Coloring Studio MVP has **Guided Color** and **Free Color**. The scored **Match the Picture** activity follows after the finite artwork and persistence foundation is proven.
- The first Coloring Studio pack contains 12 original drawings: three Fruit, three Animals, three Trees/Nature, and three Rooms.
- No mandatory account or cloud sync at launch. Projects and progress remain local; export/import can follow after schemas stabilize.
- Room projects, illustrated designs, Coloring projects, Learning progress, saved colors, and palettes form one installation-local My Work library. Existing game-player profiles own only game progress, rewards, and game settings; deleting a game profile must not delete My Work.

### Release-scope legend

- **Launch:** required for the first monetized public v1. Every checklist task is Launch unless it is explicitly classified Conditional v1, Post-launch, or Deferred.
- **Conditional v1:** MASK-02, MASK-03, MASK-04, MASK-07, MASK-09, MASK-10, MASK-12, and EXTMASK-01 target v1, but depend on independent human evidence. They block exposure and marketing of smart proposals—not the whole app—when the documented fallback keeps those controls disabled. If any smart proposal ships, every Conditional v1 task and its smart-feature gate becomes mandatory.
- **Post-launch:** MASK-13, ILL-14, ILL-15, LEARN-09, LEARN-10, COLOR-13, COLOR-14, and all Phase 14 tasks. They stay in the full product roadmap but do not block v1.
- **Deferred:** COLOR-15 and every item in the Explicitly Deferred Backlog. They require a new approved design before implementation.
- Phase 12 banner ads remain part of the planned monetized v1 because the user selected banner-only revenue. Shipping v1 without ads is allowed only through a later explicit product decision, followed by matching privacy/store verification.

## 4. Approaches considered

### Approach A — Build every feature in parallel

This creates visible breadth quickly but multiplies schema, navigation, regression, and UX risk. It also delays a trustworthy Room Visualizer because multiple unfinished systems compete for attention.

### Approach B — Quality-first staged delivery

Build the shared foundation, make Room dependable, improve Illustrated Rooms, add structured Learning, add Coloring Studio, polish existing Games, prepare release, then add ads. This is the recommended approach and the one assumed by this document.

### Approach C — Game-first growth

Coloring and casual games can increase session time, but the market is crowded and a close object-color-matching competitor already exists. Starting here would leave startup, mask quality, and project-loss problems unresolved and would weaken the Room Visualizer title.

## 5. Goals

- A new user understands the app’s purpose in the first session.
- Sample rooms, Color Learning, and Games work before any Room AI model download.
- Real-room work is recoverable, editable, and explainable.
- AI assistance reduces correction effort without hiding uncertainty or overwriting user intent.
- Illustrated Rooms provide predictable surface editing and reusable palettes.
- Color Learning teaches concepts through interaction, not just tool labels.
- Coloring Studio offers calm, original, accessible artwork completion and later supports scored learning.
- Existing games retain all durable progress and become consistent, accessible, and reliable.
- Layouts adapt across supported phone and tablet sizes, orientations, text scales, safe areas, and input methods.
- No core action depends on ad availability, consent, network, payment, or account creation.
- Every release claim is backed by tests or measured evidence.

## 6. Non-goals and anti-goals

### Non-goals for the initial product

- Live AR video repainting.
- Full 3D room reconstruction.
- Cloud/generative room redesign.
- Automatic furniture replacement.
- Mandatory account, social feed, or cloud sync.
- Proprietary paint-brand catalogues or purchase matching.
- A huge Happy Color-style content catalogue.
- Desktop/web parity.
- Physically calibrated paint or pigment prediction.

### Anti-goals

- Do not block the whole app behind a model download.
- Do not lose real-room edits on normal restart.
- Do not label mask coverage as confidence or accuracy.
- Do not silently recolor unrelated illustrated surfaces.
- Do not diagnose vision, ability, or health from Color Match or vision plates.
- Do not teach that all apples are red or all leaves are green; match each authored reference.
- Do not copy competitor artwork, licensed characters, layouts, animations, or wording.
- Do not put banners beside navigation, editor tools, camera controls, or active gameplay.
- Do not require or encourage ad clicks.
- Do not claim completion while relevant tests, analysis, migrations, or builds are failing.

## 7. Product information architecture

### Home

- Continue the most recent Room, Coloring, Learning, or Game activity.
- Four primary cards: Rooms, Learn Color, Color Games, My Work.
- Sample-room quick start without permissions or downloads.
- Clear offline state and model-download status when relevant.

### Rooms

- **Use My Room Photo:** real-photo AI workflow.
- **Try an Illustrated Room:** six existing templates and saved designs.
- Recent room projects and variants.

### Learn

- Learn, Experiment, and My Work sections.
- Foundation lessons, interactive tools, quizzes, glossary, and notebook.
- Existing mixer, formula, harmonies, matching, capture, and palette tools remain reusable.

### Games

- Learn with Color: Color Match and later Match the Picture.
- Color Logic: Water Sort and Rainbow Rings.
- Play and Relax: Bubble Shooter and Fruit & Veggie Pop.
- Coloring Studio is a prominent creative activity, not forced into the endless scored-game generator.

### My Work

- Real-room projects.
- Illustrated-room designs.
- Coloring projects and completed art.
- Saved colors, palettes, and learning experiments.
- Local data-management actions with clear deletion scope.

### Local ownership contract

- **Installation-local shared library:** Room projects/photos/masks, illustrated designs, Coloring projects, Learning progress/notebooks, saved colors, and palettes.
- **Game-profile-owned:** existing game attempts, levels, scores, coins, badges, and per-player game preferences.
- Home Continue and My Work read the shared library; the current game profile affects Games only.
- Deleting a game profile never deletes shared My Work. “Delete all app data” is a separate, explicit settings action with a category summary and confirmation.
- No account, background upload, or implied cross-device sync exists at launch.

## 8. Responsive UI contract

Responsive behavior is based on available constraints, not device-name checks.

### Width classes

- **Compact, under 600 logical pixels:** bottom navigation, one-column content, full-screen canvas, tools in collapsible rail or bottom sheet.
- **Medium, 600–839:** navigation rail where height permits, two-column galleries, canvas plus collapsible inspector.
- **Expanded, 840–1199:** navigation rail, persistent side inspector, multi-column libraries.
- **Large, 1200 and above:** centered maximum content widths; optional three-pane library/detail/editor layouts where they materially help.

### Layout rules

- Use LayoutBuilder and MediaQuery constraints; do not branch on phone/tablet model.
- Respect SafeArea, keyboard insets, system bars, display cutouts, and foldable display features.
- No fixed-height control stack may overflow in landscape or at large text.
- Content pages scroll; editor canvases remain flexible and give controls a reachable overflow path.
- Orientation change preserves current draft, zoom intent where safe, selected tool, and unsaved user work.
- Touch targets are at least 48 logical pixels unless a platform control provides a larger semantic target.
- Primary actions remain reachable with one hand on compact screens and do not sit beneath banners.
- Mouse/trackpad hover is optional enhancement; keyboard/switch focus order and activation are required on supported large-screen environments.

### Text, motion, and color

- Verify nonlinear text scaling up to at least the platform equivalent of 200%.
- Do not truncate critical labels, scores, errors, or consent choices.
- Honor reduced-motion settings; completion remains understandable without animation.
- Never communicate identity, correctness, mask ownership, or game state by hue alone.
- Provide names, numbers, icons, outlines, patterns, or text equivalents.
- Test light and dark themes and high-contrast boundaries.

### Canvas rules

- Each editor has one authoritative coordinate transform shared by its rendering, hit testing, gestures, persistence mapping, and export; reusable transform contracts/utilities are shared where appropriate.
- Pan/zoom never commits an accidental edit.
- A second finger cancels an unfinished stroke where drawing tools are active.
- Tiny regions have zoom/focus assistance and a list-based accessible alternative.
- Editor controls are not included in exports.
- Active editors and gameplay never contain ads.

### Required layout test matrix

- 320×568 compact portrait.
- 360×800 common Android portrait.
- 390×844 modern iPhone portrait.
- 568×320 and 844×390 compact landscape.
- 600×960 small tablet.
- 800×1280 Android tablet.
- 1024×1366 large tablet.
- 1280×800 landscape tablet.
- Text scaling at default, intermediate, and 200%.
- Light/dark, reduced motion, RTL, long localized strings, keyboard visible, and safe-area variations.
- Android resizable multi-window, iPad split view/Stage Manager widths, live window resize, and foldable hinge/posture cases.
- System font and display scaling combinations plus an external keyboard on at least one tablet.

Before Android public release, real-device checks include at least one lower-memory Android phone, one current mainstream Android phone, and one Android tablet. Before iOS public release, they include at least one supported iPhone and one supported iPad. Shared behavior and data formats must remain compatible across both release tracks.

## 9. Master work breakdown

Each checkbox is a tracked product task. Detailed file-level steps are written only after this design is approved.

### Phase 0 — Baseline and delivery controls

- [ ] **BASE-01 Preserve the working tree.** Record the TintAtlas branch, protect the existing lib/main.dart change, and avoid unrelated formatting or cleanup.
- [ ] **BASE-02 Establish a truthful baseline.** Run the current focused/full tests, analyzer, formatter check, and available builds; record pre-existing failures rather than hiding them.
- [ ] **BASE-03 Inventory schemas and routes.** Document current Hive boxes, repositories, route ownership, model assets, exports, platform IDs, and user-visible Color Lab branding.
- [ ] **BASE-04 Create a verification ledger.** Track every task, acceptance evidence, known limitation, migration, and device check.
- [ ] **BASE-05 Define dependency and size budgets.** Record APK/IPA size, first-frame time, model size, project-storage growth, peak memory, and acceptable package additions.
- [ ] **BASE-06 Add/repair continuous verification.** Run formatting, analysis, unit/widget suites, migration tests, and Android build in repeatable commands; add CI only after local commands are stable.
- [ ] **BRAND-01 Screen the TintAtlas identity before asset lock.** Check likely conflicts across intended app stores, package/domain/social availability, and launch markets; record findings and rename before publication if clearance is not acceptable. This is a product screen, not a substitute for professional legal advice.
- [ ] **IDENTITY-01 Confirm publication history before changing identifiers.** If any production listing or signed install already exists, preserve immutable application IDs and plan compatible upgrade/data migration; otherwise record that a new identifier is safe to establish.
- [ ] **SUPPORT-01 Lock the supported platform contract.** Start from the current Android API 24/iOS 13 floors, verify model and plugin feasibility, target-store requirements, supported release architectures, and iOS release readiness; any proposed floor increase requires measured evidence and user approval.

**Exit gate:** known baseline, protected user work, no unexplained failures, a reproducible verification command set, screened identity, and an approved platform-support contract.

### Phase 1 — Identity, shell, startup, and onboarding

- [ ] **SHELL-01 Rename product surfaces.** Replace Color Lab runtime branding with TintAtlas in app title, onboarding, platform labels, settings, shares, exports, and accessibility text.
- [ ] **SHELL-02 Finalize application identity.** After IDENTITY-01 and BRAND-01, set the approved lowercase Android/iOS identifiers, signing placeholders, display names, and migration/release notes before store publication.
- [ ] **SHELL-03 Create brand assets.** Produce original icon, adaptive Android icon, iOS icon set, splash treatment, and monochrome notification-safe mark with license/source records.
- [ ] **SHELL-04 Implement adaptive root navigation.** Home, Rooms, Learn, and Games use bottom navigation on compact layouts and a rail on larger layouts while preserving nested navigation state.
- [ ] **SHELL-05 Build the room-first Home.** Provide sample-room quick start, Continue, clear pillar cards, and My Work access.
- [ ] **SHELL-06 Replace onboarding.** Explain the three pillars, offline/local behavior, optional permissions, and deferred Room AI download; keep Skip and replay.
- [ ] **SHELL-07 Remove the global model gate.** Mount the router without Room models and initialize/download models only inside Use My Room Photo.
- [ ] **SHELL-08 Externalize strings.** Add localization delegates, English resource coverage, pluralization, locale-safe formatting, and RTL-ready layouts.
- [ ] **SHELL-09 Strengthen settings.** Appearance, privacy, licenses, model storage/download management, data deletion, tour replay, and accessibility preferences.
- [ ] **SHELL-10 Define friendly global states.** Loading, offline, permission denied, unsupported image, low storage, corrupt local data, and retry behavior.
- [ ] **SHELL-11 Make navigation recoverable.** Verify system Back/predictive Back, iOS back gesture, safe internal/deep-link routes, nested-tab restoration, process-death restoration, and unsaved-edit confirmation without duplicate screens or lost drafts.
- [ ] **SHELL-12 Establish the adaptive design system.** Define semantic color roles, typography/text scaling, spacing, shape, elevation, focus/pressed/disabled/error states, touch targets, dark/high-contrast behavior, and reusable loading/empty/error components.
- [ ] **SHELL-13 Migrate every existing route to responsive primitives.** Maintain a route-by-route ledger covering the width classes, scroll behavior, compact landscape, keyboard insets, safe areas, and long/RTL text; fixed dimensions require a documented canvas/media reason.

**Exit gate:** a fresh offline install can enter sample rooms, Learn, and Games without a Room model or permission request; brand and navigation are consistent at every required size.

### Phase 2 — Durable local data foundation

- [ ] **DATA-01 Create a schema and ownership registry.** Version Room projects, Illustrated designs, Coloring projects, Learning progress, Games profiles, colors, palettes, and preferences independently; enforce the shared-library versus game-profile contract.
- [ ] **DATA-02 Use atomic repositories.** Serialize writes, flush before success, retain the last valid record, and avoid destructive auto-reset on corruption.
- [ ] **DATA-03 Add migration fixtures.** Preserve current saved colors, palettes, game profiles/progress, and illustrated designs across every schema change.
- [ ] **DATA-04 Isolate corruption.** One bad project/record must not hide or delete healthy records; retain unreadable originals for recovery where practical.
- [ ] **DATA-05 Define storage ownership.** Every photo, mask, thumbnail, export, model, cache, and database record has a documented owner and deletion lifecycle.
- [ ] **DATA-06 Provide storage failure UX.** Visible pending/saved/error state, retry, low-storage explanation, and no false “Saved” confirmation.
- [ ] **DATA-07 Prepare backup/export later.** Stabilize versioned formats now so local export/import can be added without exposing internal Hive implementation.

**Exit gate:** migration and failure-injection tests prove current user libraries and game progress survive the foundation changes.

### Phase 3 — Real-photo Room Studio foundation

- [ ] **ROOM-01 Add on-demand model setup.** Show exact aggregate size, Download/Later/Retry, progress, verification, cancellation, resume strategy, storage error, and offline cached reuse.
- [ ] **ROOM-02 Preserve model integrity.** Keep pinned size/hash/license verification, private storage, atomic promotion, and safe incompatible-model handling.
- [ ] **ROOM-03 Create durable Room projects.** Persist prepared photo, AI baseline, current masks, explicit user intent, colors, revisions, metadata, and thumbnail.
- [ ] **ROOM-04 Add project library.** Continue, open, rename, duplicate, compare, and delete with clear photo/storage consequences.
- [ ] **ROOM-05 Autosave committed edits.** Recover after process death without storing incomplete strokes or replacing the last valid project.
- [ ] **ROOM-06 Improve acquisition errors.** Distinguish permission, unavailable camera, unsupported format, oversized input, processing, model, and storage failures with appropriate actions.
- [ ] **ROOM-07 Allow manual fallback.** When AI cannot analyze, create an empty aligned mask draft so the user can still mark surfaces.
- [ ] **ROOM-08 Standardize export.** Save image and Share on both platforms; disclose working resolution and never claim original-resolution output unless originals and coordinate mapping are retained.
- [ ] **ROOM-09 Add color variants.** Save lightweight A/B color alternatives without duplicating photo/mask data unnecessarily.
- [ ] **ROOM-10 Bound async work.** One active plus latest pending recolor, stale-result rejection, worker timeout/replacement, background handling, and predictable cancellation.
- [ ] **ROOM-11 Explain preview limits at the decision point.** State that display calibration, camera processing, lighting, wall texture, finish, surrounding colors, and real paint can change appearance; previews guide exploration and are not calibrated purchase matches.
- [ ] **ROOM-12 Minimize photo access and metadata.** Prefer scoped/system photo pickers over broad media permission, define EXIF/location stripping or retention for internal copies, and prove generated/shared exports do not leak unintended source metadata.

**Exit gate:** a real-room project survives restart, refresh, failed replacement, low storage, navigation, theme/orientation changes, and export failure without losing its last acknowledged state; photo access, metadata, and preview limitations match the stated privacy/product contract.

### Phase 4 — Smarter AI-assisted mask correction

- [ ] **MASK-01 Add guided mask review.** Surface-by-surface Check Masks flow over original/recolored views, including absent surfaces and honest coverage labels.
- [ ] **MASK-02 [Conditional v1] Add Smart Remove MVP.** Tap a leaked object/patch, generate a bounded connectivity/edge/depth proposal, preview it, then Apply or Cancel.
- [ ] **MASK-03 [Conditional v1] Add Smart Add MVP.** Suggest a bounded missing region for the selected surface without changing other owners.
- [ ] **MASK-04 [Conditional v1] Add exact command semantics.** Every proposal is one undoable command; cancel changes zero pixels; stale proposals cannot apply after photo/layer/revision changes.
- [ ] **MASK-05 Improve manual precision.** Redo, smaller high-zoom brush, visible brush outline, magnifier, source-aligned zoom, and bounded memory history.
- [ ] **MASK-06 Store user intent.** Explicitly protect corrected pixels/regions so AI refresh or model upgrades cannot overwrite them silently.
- [ ] **MASK-07 [Conditional v1] Add conservative cleanup.** Previewed small-island removal/hole fill that abstains on ambiguous or large regions.
- [ ] **MASK-08 Preserve existing protections.** Retain and test current depth protection, exclusive ownership, and existing spatial multi-wall support rather than reimplementing them.
- [ ] **MASK-09 [Conditional v1] Prepare and freeze independent quality data.** Keep the repository annotation protocol binding, validate the tooling/package, record lawful provenance, and freeze the evaluation set before tuning the candidate behavior.
- [ ] **MASK-10 [Conditional v1] Measure quality honestly.** Per-layer IoU/Dice/precision/recall, boundary quality, protected-object leakage, genuine-wall retention, and correction effort.
- [ ] **MASK-11 Freeze performance gates after baseline measurement.** Launch manual brush feedback targets under 100 ms. If smart proposals are enabled, provisional targets are proposal p95 around 1 second and committed preview p95 around 1.5 seconds on named supported devices. Once baseline measurement records feasible values, missing an approved gate requires a documented scope/device change and user approval.
- [ ] **MASK-12 [Conditional v1] Use an explicit usefulness decision rule.** Launch assistance only if all safety/reversibility gates pass, median correction time improves over the manual baseline, mean IoU regresses by no more than one percentage point, and protected-object leakage does not worsen. A 25% time reduction and 10% relative leakage reduction are stretch goals, not permission to hide weaker results; an unsuccessful proposal feature remains disabled while manual precision improvements may still ship.
- [ ] **MASK-13 [Post-launch] Evaluate model changes only with evidence.** License, size, memory, heat, latency, offline behavior, rollback, and annotated benefit are mandatory.
- [ ] **EXTMASK-01 [Conditional v1] Secure the required human evidence.** The product owner supplies or commissions 24 lawfully usable representative photos, two independent human annotators, and a third human adjudicator under the repository protocol. Code, AI-generated substitutes, or developer self-scoring cannot satisfy this external dependency.

**Exit gate:** manual review/precision/user-intent work is reversible, durable, and passes its performance/regression checks. Any enabled smart proposal also requires the frozen independent human set and real-device evidence to pass MASK-12. If EXTMASK-01 is unavailable or MASK-12 fails, the app may release with manual improvements only; smart proposal controls and claims remain disabled rather than fabricated.

### Phase 5 — Illustrated Room improvements

- [ ] **ILL-01 Simplify entry.** Choose a Look, Change a Surface, Save, Compare, and My Designs are understandable without implementation vocabulary.
- [ ] **ILL-02 Make editing predictable.** The first custom surface edit changes only that surface; Apply Complete Look is explicit and undoable.
- [ ] **ILL-03 Add Undo/Redo.** Complete-look, single-surface, comparison, and restore actions have clear history semantics.
- [ ] **ILL-04 Connect My Palettes.** Browse saved palettes and explicitly assign a copied swatch to the active surface without mutating the source palette.
- [ ] **ILL-05 Add safe comparison.** Pin a baseline, temporary B&W/original preview, and A/B variants without destructive reset.
- [ ] **ILL-06 Improve design persistence.** Save, Update, Save a Copy, Rename, Delete, recoverable draft, and schema migration preserving current appearance.
- [ ] **ILL-07 Standardize export.** Clean PNG, Share, and optional labeled palette card with HEX values and preview limitations.
- [ ] **ILL-08 Introduce shared region identities.** Stable artwork/region IDs, localized labels, fill groups, geometry, hit order, and revisions.
- [ ] **ILL-09 Pilot individual surfaces.** Split one template into back/side/accent walls and individual furniture before migrating all six rooms.
- [ ] **ILL-10 Add group operations.** All Walls and declared furniture groups affect exactly their member regions.
- [ ] **ILL-11 Expand all templates after the pilot.** Migrate saved designs safely and validate hit/render/export parity.
- [ ] **ILL-12 Curate brand-neutral starter palettes.** Create a small versioned collection of original room combinations with generic descriptive names and standard color values; do not copy Asian Paints or another brand's proprietary shade names, codes, images, recommendations, or article wording.
- [ ] **ILL-13 Make starter palettes safe to use.** Bundled palettes are read-only defaults that users may copy/customize; projects retain color snapshots across catalogue revisions, and removing or renaming a default never changes saved work.
- [ ] **ILL-14 [Post-launch] Add illustrative lighting.** Neutral Daylight, Warm Evening, and Cool Daylight preserve base HEX assignments and carry a non-calibrated-preview notice.
- [ ] **ILL-15 [Post-launch] Add finish previews.** Matte/satin/gloss require authored material/highlight masks and representative review; no flat global brightness shortcut.

**Exit gate:** existing saved designs reopen unchanged, individual edits are predictable, palette reuse is explicit, comparisons are non-destructive, and every supported layout can edit/export.

### Phase 6 — Color Learning

- [ ] **LEARN-01 Restructure Color Lab.** Learn, Experiment, and My Work expose existing tools through a coherent learning path.
- [ ] **LEARN-02 Ship Color Foundations.** Six short lessons: color coordinates, hue, saturation, lightness/value, digital mixing, and palette relationships.
- [ ] **LEARN-03 Use a consistent lesson loop.** Predict → Manipulate → Observe → Explain → Apply → Check.
- [ ] **LEARN-04 Add contextual teaching.** Expandable glossary/explanations beside HSL, RGB/HEX, LAB, CMYK, harmony, mixing, formula, and delta-E uses.
- [ ] **LEARN-05 Persist meaningful progress.** Store current step, completion, practice, answer history, topics to revisit, and intentional reset without treating game coins as mastery.
- [ ] **LEARN-06 Add concept checks.** Two or three accessible questions per lesson, explanations for every answer, free retry, and no correctness lock on lesson completion.
- [ ] **LEARN-07 Add Experiment Notebook.** Save title, lesson, input colors, model/settings, result palette, and learner observation; reopen exact state.
- [ ] **LEARN-08 Connect application tasks.** Use a learned palette in an Illustrated Room or Coloring Studio without losing the lesson state.
- [ ] **LEARN-09 [Post-launch] Add advanced tracks.** Art/Design, Digital Color, and Paint/Materials with explicit prerequisites and scientific models.
- [ ] **LEARN-10 [Post-launch] Add Contrast and Context.** Side-by-side background experiments and calculation labels that do not certify an entire design.
- [ ] **LEARN-11 Preserve scientific boundaries.** Digital LAB/RGB interpolation is not pigment mixing; formula is not a paint recipe; harmony is not a universal beauty rule.
- [ ] **LEARN-12 Keep vision plates optional and non-diagnostic.** Never require them for curriculum completion or accessibility evaluation.
- [ ] **LEARN-13 Provide nonvisual alternatives.** Core progress never depends only on subtle color discrimination.

**Exit gate:** a fresh offline install completes every foundation lesson, quiz, experiment save/reopen, and accessible alternative without Room models, account, camera, or network.

### Phase 7 — Coloring Studio

- [ ] **COLOR-01 Define original artwork contract.** Stable drawing ID/revision, localized metadata, intrinsic bounds, ordered layers, fillable/required flags, region IDs, labels, and target slots.
- [ ] **COLOR-02 Use one geometry source.** Generate display and hit data together; validate holes, overlaps, drawing order, bounds, and labels.
- [ ] **COLOR-03 Build transform-safe renderer.** Pan, zoom, fit, hit testing, selection, highlight, screen rendering, and export use the same coordinates.
- [ ] **COLOR-04 Create the catalog.** Continue Coloring plus Fruit, Animals, Trees/Nature, and Rooms filters, difficulty, mode, and progress.
- [ ] **COLOR-05 Produce 12 original MVP drawings.** Three per category, clear licenses/source notes, large regions, approximately three to five colors, and no copied/licensed competitor content.
- [ ] **COLOR-06 Add Guided Color.** Select numbered/labeled swatch, fill matching region, wrong tap leaves art unchanged with gentle feedback, free Find Region, auto-next, and no timer/score/lives.
- [ ] **COLOR-07 Add Free Color.** Select region and apply suggested, saved-color, saved-palette, or custom HEX values with Undo/Redo.
- [ ] **COLOR-08 Persist projects.** Installation-local project ID, drawing revision, mode, assignments, progress, bounded history, timestamps, atomic writes, and recoverable thumbnails.
- [ ] **COLOR-09 Build completion/My Artwork.** Resume, duplicate version, Finish, export PNG, Share, delete, and clear distinction between editable project and exported image.
- [ ] **COLOR-10 Bridge Color Lab.** Open from Learn, use My Colors/My Palettes, return to project, and keep copied assignments after source deletion.
- [ ] **COLOR-11 Bridge Rooms carefully.** Use completed palette in Illustrated Room through explicit assignment; room design and coloring state remain separate.
- [ ] **COLOR-12 Provide accessible region list.** A screen-reader/keyboard user can select a region, apply a labeled swatch, undo, find remaining regions, complete, and export.
- [ ] **COLOR-13 [Post-launch] Add scored Match the Picture.** Exact-swatch easy levels; similar-shade medium levels; target-memory/mixing hard levels; wrong required region can score zero; free retry.
- [ ] **COLOR-14 [Post-launch] Keep scoring honest.** Equal required-region weighting, reproducible rule/art revisions, hue/saturation/lightness feedback, and perceptual distance labeled as points rather than accuracy percentage.
- [ ] **COLOR-15 [Deferred] Add freehand brushes.** Add clipped freehand tools only after tap-to-fill geometry, persistence, export, and accessibility are stable and a new design is approved.

**Exit gate:** all 12 drawings work entirely offline, every committed change survives restart, export is clean, Guided and Free modes never overwrite one another, and the workspace is ad-free.

### Phase 8 — Existing Games

- [ ] **GAME-01 Preserve all five stable GameIds and migrations.** No existing profile, progress, level batch, badge, coin, leaderboard, or first-clear reward is lost.
- [ ] **GAME-02 Reorganize the hub.** Learn with Color, Color Logic, Play and Relax, plus Coloring Studio.
- [ ] **GAME-03 Add first-play tutorials.** Short, skippable, replayable, and accessible instructions for each game.
- [ ] **GAME-04 Standardize lifecycle.** Pause/resume, backgrounding, interrupted-level recovery, restart confirmation, and storage-failure feedback.
- [ ] **GAME-05 Fix the baseline failures.** Reproduce and resolve current game test/behavior mismatches before adding progression.
- [ ] **GAME-06 Polish Bubble Shooter.** Clear trajectory/bounce preview, next bubble, fair generation, non-color cues, and canvas accessibility alternative where practical.
- [ ] **GAME-07 Polish Fruit & Veggie Pop.** Clear goals, reliable swipe feedback, no-move detection/shuffle, deterministic rewards, and accessible board status.
- [ ] **GAME-08 Polish Water Sort.** Multi-step Undo, optional free Hint, restart, impossible-state protection, pattern labels, and stable pour animation.
- [ ] **GAME-09 Polish Rainbow Rings.** Selection/move preview, deterministic progression, pattern/symbol identity, and stable pause/resume.
- [ ] **GAME-10 Connect Color Match to Learning.** Optional practice entry, hue/saturation/lightness feedback, stored attempt explanation, and no diagnostic claim.
- [ ] **GAME-11 Standardize preferences.** Sound, music, haptics, reduced motion, and consistent semantics/tooltips.
- [ ] **GAME-12 Keep gameplay ad-free.** Ads may appear only on a safe hub or settled result after the later ads phase.
- [ ] **GAME-13 Isolate profile deletion.** Explain the exact game data removed and prove that deleting or switching a game profile cannot remove or hide shared Rooms, Learning, Coloring, colors, or palettes.

**Exit gate:** all current games retain progress, pass focused/regression tests, recover from lifecycle transitions, and remain playable without relying on hue alone.

### Phase 9 — Accessibility, localization, and device QA

- [ ] **A11Y-01 Audit every route with TalkBack and VoiceOver.**
- [ ] **A11Y-02 Verify keyboard/switch focus order, activation, escape/back, and modal focus restoration.**
- [ ] **A11Y-03 Verify 200% text and narrow/landscape overflow across the required matrix.**
- [ ] **A11Y-04 Add non-color identity to masks, games, quizzes, palettes, scores, and validation states.**
- [ ] **A11Y-05 Verify reduced motion, contrast, touch targets, semantics labels, live regions, and error announcements.**
- [ ] **L10N-01 Verify every user-visible string is externalized.**
- [ ] **L10N-02 Verify pluralization, dates/numbers, long strings, RTL mirroring, and no concatenated grammar.**
- [ ] **L10N-03 Select later launch languages using audience evidence and require human review rather than machine-only publication.**
- [ ] **DEVICE-01 Run the responsive layout matrix in widget/screenshot tests.**
- [ ] **DEVICE-02 Run real-device camera/photo/model/export tests per release platform.** Complete the Android matrix before Android publication and the iPhone/iPad matrix before iOS publication; never infer one platform's result from the other.
- [ ] **DEVICE-03 Measure memory, heat, battery, model latency, recolor latency, scrolling, and animation stability.**
- [ ] **DEVICE-04 Exercise adaptive window behavior.** Resize during active edits; test Android multi-window, iPad multitasking, fold hinge/posture, display scaling, external keyboard, keyboard inset, and orientation changes without state loss or unreachable controls.
- [ ] **UXQA-01 Run moderated first-use validation before beta.** With representative new users and no coaching, verify they can explain Rooms/Learn/Games, start a sample room, edit/save/export, understand local photo handling and optional model download, and recover from one realistic error; log severity and retest material fixes.

**Exit gate:** no critical workflow is blocked by screen size, window mode, text/display scale, orientation, assistive technology, input type, or locale direction on supported platforms, and moderated first-use findings contain no unresolved launch-blocking confusion.

### Phase 10 — Privacy, security, performance, and reliability

- [ ] **QUALITY-01 Threat-model local files.** Validate filenames/IDs, private storage, traversal resistance, size limits, decode limits, and deletion ownership.
- [ ] **QUALITY-02 Keep photos private by default.** Never send room photos, drawings, palettes, or content-derived labels to ad targeting.
- [ ] **QUALITY-03 Verify model/art provenance.** Ship complete license, notice, source, checksum, and content-usage records.
- [ ] **QUALITY-04 Build failure-injection coverage.** Disk full, corrupt records, killed writes, network loss, denied permissions, no ad fill, model mismatch, export cancellation, and stale async results.
- [ ] **QUALITY-05 Maintain bounded resources.** Cache limits, thumbnail regeneration, history budgets, worker disposal, image dimensions, and storage cleanup.
- [ ] **QUALITY-06 Avoid hidden telemetry at launch.** Use store-console operational data initially; any later crash/analytics SDK needs separate disclosure and approval.
- [ ] **QUALITY-07 Add in-app support diagnostics.** Privacy-safe version/build/model status and user-copyable error information without photos or personal content.

**Exit gate:** security/privacy disclosures match observed behavior, failures retain last valid user work, and performance budgets pass on the named device matrix.

### Phase 11 — Store and core release preparation

- [ ] **REL-01 Reconcile release identity.** Verify approved application IDs, bundle IDs, display names, versioning, signing records, store records, upgrade path, and branding all match the decisions frozen in Phase 0/1.
- [ ] **REL-02 Finalize signing and release configuration.** Remove example IDs and debug signing from production.
- [ ] **REL-03 Build accurate store metadata.** Title, short/full description, keyword strategy, category, feature graphic, icon, and localized screenshots.
- [ ] **REL-04 Lead screenshots with Rooms.** Real-room recolor, mask correction, illustrated rooms, learning, then Coloring Studio/Games.
- [ ] **REL-05 Complete audience/content declarations.** Truthful 13+ proposal, content rating, Families analysis, and no kids-specific metadata unless strategy changes.
- [ ] **REL-06 Draft privacy materials.** Prepare the public policy, support contact, local-photo behavior, model downloads, exports, planned ad SDK collection, Play Data Safety, and Apple App Privacy answers for reconciliation after the actual ad build.
- [ ] **REL-07 Verify all content rights.** Original artwork, fonts, model licenses, color-name data, sounds, icons, and notices.
- [ ] **REL-08 Run pre-ad controlled testing.** Exercise the ad-free core through internal and closed testing, including rollback and migration checks.
- [ ] **REL-09 Freeze the verified core candidate.** Require clean format/analyzer/tests plus the release build/archive, install/upgrade/restart/offline/device checks, and no unresolved P0 issue for the platform currently being prepared before adding the isolated ad layer.

**Exit gate:** the ad-free core is a verified candidate, identity/rights/signing/metadata are prepared, and no public release has occurred.

### Phase 12 — Google AdMob banner-only, last

- [ ] **ADS-01 Add the official Google Mobile Ads Flutter integration only after core release quality.**
- [ ] **ADS-02 Use development test IDs until release configuration.**
- [ ] **ADS-03 Implement UMP consent flow.** Refresh consent information, show required forms, expose privacy options, and request ads only when allowed.
- [ ] **ADS-04 Configure truthful age treatment and regional privacy behavior after the audience decision is final.**
- [ ] **ADS-05 Use compact adaptive banners with reserved fixed space and safe-area/layout review.**
- [ ] **ADS-06 Allow banners only on approved low-interaction locations:** Home/hubs, selected lists, saved/read-only libraries, and settled result screens.
- [ ] **ADS-07 Exclude banners from active/private flows.** Do not show them in onboarding, consent, camera, picker, Room masks/editor, illustrated editor, Coloring workspace, active gameplay, permissions, loading, or error screens.
- [ ] **ADS-08 Separate ads from controls/navigation with non-clickable space; never overlay, shift a pending tap target, imitate content, or create a dead-end ad screen.**
- [ ] **ADS-09 No-fill/offline/consent failure keeps every feature usable and collapses or safely reserves the slot without an error gate.**
- [ ] **ADS-10 Complete app-ads.txt, store declarations, Apple tracking/privacy review, and production AdMob App ID/ad-unit setup.**
- [ ] **ADS-11 Test orientation, small screens, tablets, text scaling, bottom navigation, refresh, backgrounding, consent regions, ATT denial where applicable, and accidental-click risk.**

**Exit gate:** only approved banners appear, no core flow or canvas is interrupted, no user is encouraged to click, and privacy/store declarations match the final SDK configuration.

### Phase 13 — Final verification and release readiness

- [ ] **FINAL-01 Reconcile final disclosures.** Match the exact SDK, consent, audience treatment, data behavior, ad locations, app-ads.txt, privacy policy, Play Data Safety, and Apple App Privacy answers in the release candidate.
- [ ] **FINAL-02 Re-run the complete quality gate after ads.** Formatting, analyzer, unit/widget/integration/migration/failure suites and all shared checks run for every candidate; the Android release build/device gate is mandatory for Android publication and the iOS archive/device gate is mandatory for iOS publication.
- [ ] **FINAL-03 Verify monetization variants.** Test consent required/not required, consent denied, privacy-options change, ATT denial where applicable, ad loaded, slow, no-fill, network loss, and invalid/test configuration without blocking any feature.
- [ ] **FINAL-04 Run the final per-platform controlled rollout.** Internal → closed → optional open/limited production testing with platform-specific crash/ANR review, migration evidence, rollback artifact, and no unresolved P0 issue.
- [ ] **FINAL-05 Require explicit publish approval.** Present signed artifact identifiers, version/build numbers, evidence ledger, known limitations, store copy, and rollout/rollback plan; publishing remains a separate user-authorized action.

**Exit gate:** signed store-ready artifacts, observed behavior, disclosures, and evidence all match after the final ad integration; the release can be published only with explicit user authorization.

### Phase 14 — Post-launch learning

- [ ] **POST-01 Monitor store health.** Crashes/ANRs, startup, download failures, ratings/reviews, model failures, and release adoption through platform consoles.
- [ ] **POST-02 Validate activation.** Observe whether users reach a sample room, complete a real-room preview, save a design, finish a lesson, or complete a coloring project using privacy-compatible measurement approved later.
- [ ] **POST-03 Prioritize evidence over feature count.** Fix mask quality, project loss, confusing navigation, accessibility, and performance before expanding catalogues.
- [ ] **POST-04 Expand content deliberately.** More lessons, room regions, artwork packs, and game levels require content QA, stable IDs, migrations, licenses, and measured demand.
- [ ] **POST-05 Review ad UX with retention.** More impressions are not a success if task completion, ratings, or return use decline.

**Exit gate:** post-launch decisions use privacy-compatible evidence, urgent reliability and usability issues take priority, and no catalogue or ad expansion bypasses the same quality gates used at launch.

## 10. Dependency order

1. BASE before all implementation.
2. SHELL before new first-session/navigation work.
3. DATA before durable Room, Coloring, or Learning records.
4. ROOM before advanced MASK proposals.
5. Shared region identity from ILL/COLOR is piloted once and reused.
6. LEARN foundation before scored Match the Picture claims educational value.
7. Existing GAME progress migration is protected before adding another scored GameId.
8. A11Y/L10N/DEVICE work is continuous, with a final independent release gate.
9. REL after all core launch features are stable.
10. ADS only after the verified core candidate and audience/privacy decisions.
11. FINAL after the exact production-shaped ad build; Phase 14 starts only after an explicitly authorized release.

Parallel work is allowed only when tasks do not edit the same subsystem or depend on an unsettled shared contract.

### Inputs that implementation alone cannot manufacture

| Input and owner | Required before | Fallback if unavailable |
|---|---|---|
| User/product owner accepts the brand screen and any professional clearance advice | Icon/store identity lock | Rename before publication |
| Product owner supplies/commissions the licensed photos and independent human annotators in EXTMASK-01 | Smart-proposal quality claim and MASK exit gate | Ship proven manual correction improvements; keep unvalidated smart proposals disabled |
| Product owner provides access to representative Android/iOS/tablet hardware and moderated-test participants | Public beta/release gate | Keep release blocked or narrow the declared support contract explicitly |
| User owns/authorizes Google Play, Apple Developer, AdMob, app-ads.txt domain, signing, and store credentials | Production-shaped candidate and publication | Continue with test IDs/local artifacts; do not publish |
| User approves final audience, privacy, store declarations, rollout, and known limitations | FINAL-05 | No public release |

## 11. Final coding workflow

### Gate 1 — Approve this master design

The user confirms product scope, Launch/Post-launch classification, recommended approach, audience proposal, package ID proposal, provisional OS floors, platform order, navigation, shared-library ownership, staged Coloring Studio modes, and the external human-evidence dependency for smart mask claims.

### Gate 2 — Write the implementation plan

Invoke the writing-plans workflow and split this design into milestone plans with:

- exact files and symbols;
- one behavior per task;
- test-first steps;
- data migrations and rollback;
- verification commands;
- dependency and parallelization boundaries;
- explicit acceptance evidence.

### Gate 3 — Execute one milestone at a time

For each task:

1. Reconfirm clean scope and preserve unrelated work.
2. Write a failing focused test.
3. Implement the smallest correct change.
4. Run the focused test.
5. Add edge/failure/accessibility/migration coverage.
6. Refactor without broad unrelated edits.
7. Run the related suite, analyzer, formatter, and diff checks.
8. Obtain an independent read-only code review.
9. Fix valid review findings and rerun verification.
10. Record evidence and known limits.

### Gate 4 — Milestone verification

- Focused and regression suites pass.
- Analyzer is clean and formatting is verified.
- Required builds succeed.
- Schema upgrade/downgrade behavior is understood.
- Responsive/accessibility/device checks match the milestone risk.
- No user work, progress, or unrelated code is lost.
- Completion claims quote current command output, not earlier results.

### Gate 5 — Handoff

After each milestone, report:

- outcome;
- files changed;
- migrations;
- verification commands/results;
- known limits;
- next recommended milestone.

Do not push, publish, upload, change store state, or add production ad IDs without explicit user authorization. Local checkpoint commits are made only under the agreed repository workflow and never include the user-owned lib/main.dart edit unintentionally.

## 12. v1 definition of complete

The first monetized public release is complete only when:

- Every checkbox classified Launch and its relevant exit gate is satisfied. Conditional v1 tasks are also satisfied for every conditional feature exposed in the candidate; otherwise the documented disabled-feature fallback is verified. Post-launch, Deferred, and Phase 14 work do not block v1.
- TintAtlas branding and release identity are final.
- First use is understandable and does not require Room models.
- Real-room projects persist; manual correction is dependable, and any enabled smart proposal is independently measured and passes MASK-12.
- Illustrated Room editing is predictable and palette-connected.
- Color Foundations works offline and progress persists.
- Coloring Studio ships original, accessible Guided and Free modes.
- The five existing games retain progress and meet their quality gates.
- Required responsive and accessibility matrices pass.
- Privacy, licensing, audience, store, signing, and release artifacts are complete.
- AdMob banners, if enabled, are last, policy-safe, optional to app function, and absent from active tools/games.
- Phase 13 final verification is current and independently reviewed after the exact ad integration.

## 13. Explicitly deferred backlog

- Live AR and real-time camera repainting.
- Full 3D reconstruction or generative redesign.
- Cloud accounts/sync/social feed.
- Brand paint catalogues and exact purchase-match claims.
- Large downloadable art marketplace.
- Freehand Drawing Studio until region coloring is stable.
- Advanced interactive-segmentation model until annotated evidence justifies it.
- Desktop/web parity.

## 14. Approval statement

The user approved this document on 2026-10-27. Approval authorizes creation of the detailed implementation-plan set, not immediate execution of every phase. Code execution begins only after the plan is presented under the agreed workflow.
