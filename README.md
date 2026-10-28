# Color Lab

An offline color studio for curious eyes and inspired spaces. Flutter, Android first (minimum SDK 24), with iOS-ready application code.

## Current app

The starter counter app has been replaced by a four-tab studio with custom Material 3 light/dark themes, bundled fonts, and reusable accessible controls.

- **Capture:** live camera sampling, system photo selection, zoomable photo sampling/loupe and dominant palettes, plus manual HEX entry. Common details include all six formats, copy/save/favorite, harmony swatches, system sharing and Use in Room.
- **Palette:** saved colors, favorites, searchable local history, whole saved palettes and Studio inspiration.
- **Lab:** HSL study, LAB/RGB mixer, approximate Color Formula search, six-mode Harmonies, a five-round matching game and original procedural vision plates, with independent session state.
- **Room:** a six-room illustrated SVG color gallery (Living, Bedroom, Study, Dining, Kitchen and Bathroom) plus separate offline AI masks for imported room photos, independent Wall/Ceiling/Floor/Furniture colors, manual Add/Erase refinement, lighting-preserving photo recoloring, Before/After, and PNG sharing.
- **Onboarding:** three illustrated, skippable first-run slides explain discovery, your offline library and permission choices. The tour can be replayed from Appearance settings.
- **Appearance:** System, Light, or Dark; defaults to System. Theme and tour completion persist locally across launches.
- **Color engine:** opaque HEX, RGB, HSL, HSV, CMYK, D65 LAB, CIE76 delta-E, cached nearest naming, weighted LAB/RGB blending, approximate base-color formulas, six HSL harmony modes, and deterministic weighted LAB k-means++ with population-conserving merging.
- **Offline assets:** Plus Jakarta Sans, JetBrains Mono, and the complete 31,943-entry color-name-list, with original licenses. JSON parsing and LAB preparation run in an isolate.

The bottom tabs are **Capture / Palette / Lab / Room**. **Use in Room** selects the illustrated Study wall, fills its other surfaces from **Quiet Sage** and opens the full-screen tester; the photo editor's four layer colors remain independent.

## Illustrated room color gallery

Open **Room → Choose an illustrated room** and choose Living room, Bedroom, Study room, Dining room, Kitchen or Bathroom. Gallery cards and a template's first editor draft are black and white. **Soft Linen**, **Quiet Sage**, **Airy Slate**, **Clay and Cream**, **Mist and Ink** and **Sunwashed Olive** are original display-only starter combinations; selecting one colors Wall, Ceiling, Floor and contextual Furniture together. The first custom surface choice seeds that room's complete starting look before applying the selected color, so previews never become partly colored.

On phones, the color tools start hidden so the room uses the full screen width; tap **Show color tools** to open the overlay rail and **Hide color tools** to close it. On tablets at 720dp or wider, the rail starts visible and can still be hidden or shown. **Fill screen** fills the viewport and may crop illustration edges, while **See whole room** preserves the complete illustration and may leave space around it. **Focus preview** hides the Back button, title, fit controls, flyout and color rail, leaving only the artwork and a safe **Exit focus preview** action; system Back exits focus before leaving the editor.

Rail visibility and Focus Preview are local editor UI state and reset when a different template is opened. The fit choice is also editor-only; none of these controls is stored in a saved design or included in an exported image. Color drafts still remain available for the app session, named designs still persist only through **Designs**, and **Save to Gallery** continues to export the clean complete artwork without any editor controls.

Drafts are retained during the app session. Durable storage is explicit: open **Designs → Save room design** to name and persist a combination in the local `illustrated_room_designs_v1` Hive library. Saved designs can be reopened, updated, renamed, filtered by room or deleted; unavailable future templates remain preserved.

**Save to Gallery** is available only after colors are applied. It renders the complete SVG artwork—not the current screen crop, rail or controls—as a clean 2400 × 1600 PNG and writes it to the system photo library only after the user taps the action. No custom album is created and no room design or photo is uploaded. Gallery export and durable design saving are separate actions.

Recommended looks are guidance, not calibrated predictions or a universal “best” color. Screens, daylight and evening light, surface texture and finish alter appearance; compare a physical paint or material swatch in the real room before purchase. The existing real-photo mask editor remains an independent workflow and does not overwrite illustrated designs.

To register another illustrated room, add an SVG under `assets/rooms/`, use the reserved fills `#FF00A1` (Wall), `#00E5FF` (Ceiling), `#B7FF00` (Floor) and `#7A00FF` (Furniture), then add its template and complete palettes to `IllustratedRoomCatalog.all`. One shared renderer/controller/screen handles every registered template.

`flutter_svg` parses SVG assets into vector graphics in an isolate. The four-color draft stays synchronous because those tiny state updates are cheaper than sending them through `compute`.

## Room masks and recoloring

On app launch, **Room Studio setup** checks saved MOSAIC segmentation and MiDaS depth models. Missing or corrupt files download automatically from the fixed [room-models-v1 GitHub Release](https://github.com/rowjoy/color_lab/releases/tag/room-models-v1), about **65.2 MiB** combined. The full-screen gate shows real aggregate download progress (1–99%), verification, then 100% before opening the existing onboarding/home flow. Failure stays on setup with **Retry setup**; valid cached files pass offline without another download. Startup verifies files without allocating inference buffers. Each file is streamed into app-private support storage, checked against its exact size and pinned SHA-256, and promoted only after verification. Clearing app data or uninstalling requires setup again. Open **Room → Visualize your room** to explicitly choose a gallery photo or take a room photo. No credentials are in the app and room photos are never uploaded. The descriptor and licenses remain bundled, but neither model binary is in the APK.

Both models run locally before editing becomes available. Wall, Ceiling, Floor and Furniture are exclusive ownership layers with independent optional colors. The After preview keeps source lightness while applying each selected color in LAB, and Before restores the source view. **Share PNG** sends only the latest fully rendered frame through the system share sheet without saving a project or requesting storage access. Under **Refine masks**, Add assigns ownership to the selected layer, Erase removes only that layer, Move allows pan/zoom, Undo restores exact prior pixels, and Restore AI masks requires confirmation. The refine overlay remains a mask-inspection view rather than the exported recolor.

**Refine masks → Edit full screen** opens the same photo and draft in a full-screen workspace with Pencil, Eraser, Move, four layer selectors, brush size, Undo, overlay visibility, zoom buttons and Fit. Pinch zoom works up to 8× in every tool. A second finger cancels an unfinished stroke; drawing resumes only after all fingers lift. Closing keeps committed edits and discards unfinished input. Zoom and brush placement share the same source-coordinate transform.

Furniture ownership includes the model's Bed, Sofa, Chair, Table, Cabinet, Shelf and Armchair predictions. The last two were previously omitted from the mapping. This fixes omitted supported categories; it does not correct the model's semantic mistakes or add a monitor class. Layer percentages describe photo coverage, not confidence or accuracy.

On 2026-10-23, the running app was tested on a physical Pixel 8 Pro using its existing room photo: Add, Eraser, Undo, the full-screen workspace, 2.3× zoom controls, Fit and closing were exercised. Test strokes were undone while retaining the user's existing edits. Two-finger cancellation/source alignment also have automated regression coverage. The combined suite passed 890 tests, with clean analysis and formatting. A separate actual-model host probe of the same 1205×1600 photo produced Wall, Ceiling and Furniture ownership; Floor was absent. Wall leakage onto monitors/desk objects remains visible. No annotated ground truth exists for this photo, so 90% detection accuracy has not been established. No iOS device or native screen-reader result is implied.

For an optional private real-photo host probe, set `COLOR_LAB_ROOM_TEST_PHOTO` to an absolute local image path when running `tool/run_room_model_smoke.dart --flutter-root <SDK path>`. The normal frozen-reference checks still run; additional ownership bytes, per-layer visual overlays and a report go only to a newly created system-temporary directory. The report explicitly distinguishes measured coverage from unavailable accuracy. Personal phone photos and screenshots are not bundled in this repository.

Working photos are oriented, composited onto white and limited to 1600px on the longest side. Acquisition accepts at most 24MiB encoded input; processing independently enforces 32MiB, 24 million decoded pixels and 16384px per axis. Masks and edits survive navigation/theme changes only during this session. The durable acquisition-intent record supports explicit recovery of unfinished native picker work; it does not save a room photo, mask, project or undo history. Replacement failures preserve the previous draft. Undo retains at most 20 commands and 16MiB.

Automatic masks can miss surfaces or include nearby objects. The reference photograph includes a person incorrectly labeled as chair/Furniture, ornate-surface errors and missed sofa/pillow areas. The small inspected sample has no dense ground truth; no accuracy percentage or universal-best claim is made. Check and refine each layer before sharing the recolored result.

Mask-quality fixes retain the same two models: coherent small foreground can now activate depth protection even when it occupies less than5% of an otherwise flat depth image; isolated spikes still do not. Selected-mask preview feathering is clipped inward to its owner, so erased/protected pixels no longer appear tinted. This corrects preview disagreement with the already owner-gated recoloring; it is not a new object detector. Fresh authorized gallery tests still reproduce monitor-to-Wall errors, so **95% accuracy has not been achieved or established**.

The bounded patch passed966 automated tests, clean analysis/formatting and Android debug build. Actual two-model host inference ran on the frozen reference and five authorized gallery photos; these are runtime/diagnostic checks, not measured accuracy. Current corner-room photos fail the single-plane60% consensus safeguard; simply lowering it would remove inspected genuine second-wall pixels. Spatially bounded multi-wall support and independent dense annotations remain necessary before that case can be claimed fixed. The running phone was inspected read-only, not restarted or replaced, preserving its current edits.

For an independent raw annotation (`0=unselected,1=wall,2=ceiling,3=floor,4=furniture,255=void`), run `dart run tool/verify_room_mask_quality.dart --prediction ownership.bin --truth independently-annotated.bin --width W --height H`. The JSON reports per-layer IoU, precision, recall and Dice, pixel accuracy, counts and input hashes. Exit0 requires at least0.95 IoU for each of the four truth-present layers and no void pixels; missing/partial annotations fail that gate rather than earning an invented success. A high background-dominated pixel score is insufficient. This scores only supplied annotations and never certifies model-wide quality. Private gallery originals, masks and screenshots stay in system temporary storage and are not bundled or committed.

Known developer-tool minor: dimension multiplication is not yet overflow-safe for impossible, extreme64-bit dimensions; normal prepared-photo dimensions are unaffected. This tool does not run in the mobile app.

The pinned 1,978,000-byte segmentation model has SHA-256 `da8b3822a22fde45ecaf0ff32022287eff58b500096971b04f3c1b292da66a3c`; the original MLCommons Association License and provenance notice ship in `assets/licenses/room-model-{LICENSE,NOTICE}.txt`. The unmodified 66,338,288-byte MiDaS model has SHA-256 `93d871071edff1218973ce25ee27ce95ccd20450c70a55e1b89efa3f5a772cdd`, with MIT license and provenance in `assets/licenses/room-depth-{LICENSE,NOTICE}.txt`. MiDaS estimates relative depth, not object classes: robust wall-plane filtering can exclude nearer objects that segmentation mislabeled as Wall, without assigning them an invented Furniture class. It can leave coarse edge halos and near-wall objects; it does not establish 90% accuracy. See [asset sources](docs/asset-sources.md) for source revisions, fixture identities and original photo attribution. The app uses `tflite_flutter 0.12.1`; the actual production runner passed host TFLite 2.11.0 checks. Mobile dependency declarations and unchanged Android24/iOS13 targets do not establish phone performance, memory/delegate behavior, device accessibility or iOS execution.

For developer smoke checks, download `room_seg.tflite` and `room_depth.tflite` from that fixed Release into local `assets/models/` (both paths are Git-ignored), then run `dart run tool/run_room_model_smoke.dart --flutter-root <SDK path>`. The tool stages fixtures and verifies the same production file-backed factory in an offline temporary cache; it does not add binaries to the APK or require a runtime network request.

GitHub delivery verification on 2026-10-23 passed **945 tests**, whole-project analysis, formatting, and a debug APK build. APK inspection found the descriptor but no `.tflite` files. With `COLOR_LAB_VERIFY_MODEL_DOWNLOADS=1`, the actual production store downloaded the public fixed Release over HTTPS, passed native reference inference and then verified a fresh store could reuse both files with network access disabled. Independent anonymous downloads matched both pinned hashes. Review found a setup-cancellation race; gated-descriptor, queued-request and rapid Cancel/Retry/Cancel regressions now pass. This is host/debug-build evidence, not a new physical-phone or iOS validation claim.

Startup setup verification passed **954 tests**, whole-project analysis, formatting and Android debug build. Its focused tests cover actual progress, the verified 100% frame, offline-ready handoff, safe retry, large text, disposal and stable navigation. The native two-model offline reference smoke also passes with the files-only preparation path. Physical-device startup UX has not yet been re-tested.

The earlier masking-only source archive is `dist/color-lab-room-masks-2026-10-22.zip`. Its historical verification was **787 automated tests**, real bundled-model/default-worker smoke, clean whole-project analysis, 186 formatted Dart files and five renderer tests producing 140 previews. That ZIP predates Fast MVP recoloring and is not its delivery artifact. Fresh recoloring verification is recorded in the [Fast MVP ledger](.superpowers/sdd/2026-10-22-room-photo-recolor-fast-mvp/progress.md); this task creates no replacement archive or APK. For the earlier masking milestone, see [final evidence](docs/superpowers/plans/room-final-verification.md), the [late fix report](docs/superpowers/plans/room-final-race-fix-report.md) and the [Room ledger](docs/superpowers/plans/2026-10-22-room-auto-masking-progress.md). The user confirmed independent build/run activity that changed APK hashes from historical `1986b60e…` to `00896bea…`. Latest observed copies hash `eb36f749379d33e82644e6c61861647ccb88c685479ff780bd3bd2959fa0a3ae` (both copies, 162,563,223 bytes, modified 2026-10-22 10:37:35+0600); the origin of this later change is not attributed. Those files are left untouched and neither APK is this source delivery. Nine earlier ZIP archive hashes remain unchanged.

## Procedural vision plates — source-only delivery

Open **Lab → Explore vision plates**, read the introduction and choose **Start activity**. Six original, untimed dot patterns are generated on-device with `CustomPaint`; no clinical plate images, raster numeral images or fonts are embedded in the pattern. Enter one digit (zero is valid) and choose **Record answer**, or choose **Not sure**. There is no correctness feedback between patterns and no expected digit hidden in the image's accessibility label.

Results describe only the six recorded responses: generated number, your response, pattern matches and Not sure count. They do **not** label vision normal/deficient, assign severity, pass/fail a medical test or rule out a condition. Generated colors, dot layouts and basic glyph masks are original illustrative choices, not calibrated or validated screening plates. The app keeps this limitation visible throughout the activity.

If you have concerns about color vision, talk to an eye care professional; [NEI describes clinician-administered testing](https://www.nei.nih.gov/eye-health-information/eye-conditions-and-diseases/color-blindness/testing-color-vision-deficiency). That guidance supports the referral copy, not clinical validity of this app. No NEI/Ishihara reference images or diagnostic answer keys are copied.

The six plates use shuffled digits 2, 3, 4, 5, 6 and 8, three illustrative color pairs and seeded geometry. Dot positions and sizes depend on the seed only; the glyph changes dot colors, not density/geometry. The same actual RGB and neutral paper render in both themes. A cached painter draws circles only, without hidden text, tracing outlines, a tap-to-reveal answer or a recolored medical image.

Pending digits and responses survive navigation/theme changes during this app session. Captured plate IDs reject stale callbacks rather than answering the next pattern. Accepted responses dismiss the keyboard, clear the draft and show the new pattern at the top. Restarting an active activity requires confirmation; **Try again** after results starts a fresh active set. Typing/theme changes preserve position. History, palettes, matching and other drafts are not altered. Nothing is persisted or transmitted by this activity.

For the historical Vision module, **no APK or native build/install was performed**. That milestone used Dart formatting, Flutter analysis/tests, real-font light/dark previews and a source ZIP only, with no new dependency, native configuration, image asset, permission or database schema. The later APK observations are described in the Room handoff above.

Historical source handoff: `dist/color-lab-vision-2026-10-21.zip`. See the [design](docs/superpowers/specs/2026-10-21-vision-plates-design.md), [plan](docs/superpowers/plans/2026-10-21-vision-plates.md) and [verification ledger](docs/superpowers/plans/2026-10-21-vision-plates-progress.md). Room masks are included in the newer cumulative source delivery above.

## Color Matching Game

Open **Lab → Play color matching**. Match the target by adjusting Hue, Saturation and Lightness, then choose **Check my match**. There is no timer. Each game has five distinct, varied target swatches; each round starts from neutral gray, not a target-derived hint. Target HEX and detail actions remain hidden until you submit.

A compact Target/Your match comparison stays visible while the sliders scroll, so both colors remain available when adjusting Lightness on a small phone.

Submission freezes that attempt. Feedback reveals the target and your actual displayed RGB shade, CIE76 delta-E (lower is closer), and points. Points are `round(clamp(100 − delta-E, 0, 100))`, a simple game convention rather than a scientific percentage. Error uses the existing D65 LAB conversion of the displayed RGB swatches. A rounded score of100 or displayed error of0.00 does **not** alone mean an exact match; that label requires identical RGB channels.

Choose **Next round**, then **See results** after the fifth attempt. Results retain all five exact target/guess pairs, per-round error and points, total out of500 and average out of100. **Play again** starts another game. **Restart game** during editing or feedback requires confirmation; cancel and Back preserve the current game. HSL coordinates retain your selected hue through gray/black/white so restoring chroma does not unexpectedly reset it.

After submission, open either swatch's common details to copy, share, save or use that exact shade in Room. Playing never automatically writes saved-color history or palettes. The game survives navigation/theme changes during this app session, independently of HSL, Mixer, Formula and Harmonies; restarting the app resets it. No account, leaderboard, database schema, dependency or platform change is needed.

Screens, lighting and surrounding colors affect perception. This is an untimed color game, **not a medical test or diagnosis**. Procedural vision plates are a separate non-diagnostic activity.

Source handoff: `dist/color-lab-matching-2026-10-21.zip`. See the [design](docs/superpowers/specs/2026-10-21-color-matching-design.md), [implementation plan](docs/superpowers/plans/2026-10-21-color-matching.md) and [verification ledger](docs/superpowers/plans/2026-10-21-color-matching-progress.md).

## Harmonies and saved palettes

Open **Lab → Open harmonies**, or **Explore harmonies** in any common color detail to start from that exact selected shade. Choose another base with manual HEX or the existing saved-color picker; cancellation preserves your draft. Base and mode remain independent of the HSL, Mixer and Formula drafts throughout this app session.

Six HSL modes are available: Complementary (+180°), Analogous (−30°/+30°), Triadic (+120°/+240°), Tetradic (+90°/+180°/+270°), Split complementary (+150°/+210°) and Monochromatic (lightness offsets −.30/−.15/+.15/+.30, clamped to 0–1). The exact base is first and duplicate displayed RGB shades are removed. The read-only wheel places red at the top, progressing clockwise, and uses the actual palette RGB colors. Monochromatic shades occupy distinct lightness positions; gray/black/white have no invented hue angle. Each tappable shade opens the existing formats/copy/share/save/Room details.

**Save palette** asks for a nonblank name (up to 80 displayed characters) and stores the whole exact ordered snapshot, not individual color-history entries. The separate version1 `color_palettes_v1` Hive box keeps name, base, mode, colors and UTC creation time under the existing app-private `color_lab` directory. No existing history/preferences schema or dependency/native configuration changes are needed. Saves include disk flush, preserve committed state on failure, and offer safe retry. Corruption is preserved, never cleared automatically.

The base/mode pair is the collection identity: repeated saves preserve the original name, date and colors. Open **Lab → Palettes** or **View saved palettes** to inspect stored colors, open an editable harmony, or confirm deletion. Opening a palette restores its base/mode into the editor without modifying its stored snapshot. A differing original snapshot is clearly labeled rather than falsely claimed as the current saved version; delete it explicitly before replacing that identity. Deleting a palette never deletes individual saved colors. Collections, favorites and color-search filters remain independent.

Harmonies are digital color studies, not calibrated physical paint/material combinations. The current draft is session-only; named saved palettes survive restart on this device. No account, synchronization, project/rename UI or automatic replacement is included.

Source handoff: `dist/color-lab-harmonies-2026-10-21.zip`. See the [design](docs/superpowers/specs/2026-10-21-harmonies-design.md), [plan](docs/superpowers/plans/2026-10-21-harmonies.md) and [verification ledger](docs/superpowers/plans/2026-10-21-harmonies-progress.md).

## Approximate Color Formula

Open **Lab → Open color formula**, or **Find color formula** in any common color detail. The latter uses that exact selected shade and closes the detail sheet before navigating. Choose another target with manual HEX or the saved-library picker; cancel preserves the existing target. The default is Lilac, and the selected target stays for this app session without resetting the HSL or Mixer drafts.

The on-device search uses twelve fixed digital bases: red, orange, yellow, green, blue, violet, white, black, yellow ochre, burnt sienna, raw umber and Payne's gray. Their exact reference HEX values are visible under **Our digital bases**. It checks every pair/triple with positive percentages in 5% steps totaling 100%, plus pure-base endpoints: up to 38,886 candidates. A zero-error result can finish early. Blending follows the existing D65 LAB mixer.

Candidates are ranked by CIE76 delta-E between the target and the **displayed** rounded/gamut-clamped RGB blend, not an invisible ideal LAB color. The screen shows both swatches, the best recipe's one to three contributions and that exact error (lower is closer). Ties retain a deterministic earlier recipe, preferring fewer contributions. Production search runs in a `compute` worker on Android/iOS. Target-keyed, auto-disposed async results prevent late success/error from replacing a newer choice and avoid a historical global result cache. Failures leave target entry available and offer **Retry formula**.

Open the resulting blend's details for formats/copy/share/Room, or save its color directly with the existing Lab source and normal same-HEX deduplication. Reopening formula from details while already on that screen updates its target without stacking another formula screen. Saving keeps only the resulting color, not a persistent recipe or project.

This is an **approximate digital formula, not a paint recipe**. The bases are illustrative sRGB references, not measured pigments; real materials, lighting, screens and physical mixing behave differently. No calibrated paint/brand or chemical accuracy is claimed. No new package, platform permission, schema or network service is required.

Source handoff: `dist/color-lab-formula-2026-10-21.zip`. See the [design](docs/superpowers/specs/2026-10-21-color-formula-design.md), [plan](docs/superpowers/plans/2026-10-21-color-formula.md) and [verification ledger](docs/superpowers/plans/2026-10-21-color-formula-progress.md).

## Color Mixer

Open **Lab → Open color mixer**. Start with Lilac and Butter at equal parts, then edit or add colors using manual HEX or your saved library. Each ingredient has 0–100 relative parts; percentages normalize automatically. Additions have no fixed count limit, and removal keeps at least two ingredients. Zero-part colors do not contribute. When every part is zero, recovery guidance replaces the output and save/details actions until a slider becomes positive.

**LAB**, the default, averages D65 L*,a*,b* coordinates by weight and converts the result into display RGB. **RGB** averages encoded sRGB display channels and rounds once; it is not linear-light mixing. Both real results appear for comparison, and choosing a mode selects the primary save/details target. A compact pinned swatch and HEX stay visible while adjusting ingredients. Neither mode simulates physical paint or pigments.

Open result details for all formats, copy/share/favorite and **Use in Room**, or save the result directly. Saved results use the existing Lab source and normal same-HEX deduplication. Manual selection remains available if the saved library cannot load; its local search does not change Palette filters. Reset requires confirmation and preserves saved colors.

The mix draft survives navigation within the current app session, including switching between HSL and Mixer. It is not a persisted recipe or project: restarting resets the draft, and saving stores only the resulting color. No new dependency, permission, platform change or database migration is required.

Source handoff: `dist/color-lab-mixer-2026-10-21.zip`. See the [design](docs/superpowers/specs/2026-10-21-color-mixer-design.md), [implementation plan](docs/superpowers/plans/2026-10-21-color-mixer.md), and [verification ledger](docs/superpowers/plans/2026-10-21-color-mixer-progress.md).

## Onboarding and persistent settings

First launch with this module presents three short, illustrated English slides. Next, Back and swiping navigate; **Skip** from any slide and **Get started** both save completion before entering Capture. The tour never requests camera/gallery permission or initializes the camera. If completion cannot be saved, it stays on the tour with a safe inline error and a retry action. Existing saved colors are untouched, including when upgrading from the earlier modules.

Appearance settings retains System/Light/Dark and About/licenses, adding durable save feedback, privacy copy and **Replay welcome tour**. Controls wait for persistence; failure keeps the last committed theme and provides inline retry feedback. Replay returns to the previous tab without resetting the theme, edited Lab study or color history.

Preferences load behind a lightweight startup screen before main content. The first main frame uses the stored theme directly, avoiding a temporary light-theme flash. Later theme changes animate normally unless reduced motion is enabled. Returning users bypass onboarding. A load failure offers explicit Retry without showing raw exceptions or clearing storage. The stable router refreshes guards in place, so changing appearance does not recreate tab navigators.

The existing Hive/path_provider dependencies store a separate version1 `app_preferences_v1` box under the same app-private directory as history. Its one preferences record contains schema version, theme name and completion flag. Mutations reload the last durable record and serialize, so a concurrent theme change and tour completion preserve both fields. Failed flushes block reads/no-op success until retried; corruption and unsupported versions are preserved. Unknown theme values fall back to System, independently of the completion flag. No new package or platform permission is added.

The source handoff for this module is `dist/color-lab-onboarding-settings-2026-10-21.zip`. See the [design](docs/superpowers/specs/2026-10-21-onboarding-settings-design.md), [implementation plan](docs/superpowers/plans/2026-10-21-onboarding-settings.md) and [verification ledger](docs/superpowers/plans/2026-10-21-onboarding-settings-progress.md).

## Camera and photo module

Choose **Open camera** to request camera access and see a portrait, cover-fit live preview. Tap or drag its colored reticle: the worker averages a clipped 5×5 frame patch, throttles to about 15fps, and smooths three samples. HEX, RGB, HSL and nearest names update live; Save records the camera source. Only one conversion runs at a time. Streams release on background/navigation and reopen on resume. Denied, restricted, unavailable and unsupported cameras offer safe recovery and photo alternatives.

Choose **Pick a photo** to use the system picker without broad library/storage access. Cancellation leaves Capture usable; Android lost picker results recover on startup. Late results never interrupt a different tab. Tap/drag to sample real pixels; dragging shows a genuine image loupe. Two fingers zoom/pan, with center-sample and reset controls. Weighted palette bars and cards show reduced-image population estimates; tapping any shade opens the same details with gallery source. A solid image correctly returns one color, not invented swatches.

Decode, orientation, white-background alpha compositing, resize and deterministic LAB k-means run in a worker isolate. Native selection requests at most 2048px; processing previews cap at 1600px and palette input at 200px. The acquisition guard is 24MiB; the worker independently rejects inputs over 32MiB, 24 million decoded pixels or 16384px on an axis before expensive decode wherever headers allow. JPEG, PNG, GIF, WebP, BMP and TIFF first frames are supported. Native pickers may convert HEIC; raw HEIC/AVIF bytes are not decoded. Channels are interpreted consistently as sRGB; wide-gamut ICC conversion and camera color calibration are not implemented.

Details provide a deduplicated neighboring/complementary harmony strip, replacement rather than stacked exploration, an actual swatch Hero from camera/photo, and a system text share containing all formats. Sharing supplies a nonzero iPad popover anchor and inline failure feedback. **Use in Room** applies the selected color to the illustrated wall study and opens Room.

## Local history module

Open any color detail from Capture, Studio, Lab, or Room and choose **Save color**. The color's name, HEX, original source, favorite status and creation time persist in an app-private Hive database across launches. A repeat save of the same HEX keeps one entry and preserves its original metadata. Saved colors appear in the Palette tab.

Search names or HEX fragments without case sensitivity, combine search with **Favorites only**, or clear the filters. Favorite changes are immediate after the durable write completes. Delete requires confirmation. Studio inspiration remains separate from your saved library.

Reads and writes serialize, and write completion includes a disk flush. If storage fails, the app retains its last successfully loaded list and offers friendly retry feedback. Pending flushes must succeed before changed records can be published; corrupted storage is never cleared automatically. Data uses validated version-1 maps with no generated adapters. There is no export/migration UI in this module yet.

## Run

Requires Flutter stable compatible with Dart 3.11. Developed and verified with Flutter 3.41.1 / Dart 3.11.0.

```sh
flutter pub get
flutter run
```

Only these runtime packages were added for Foundation:

```yaml
flutter_riverpod: ^3.3.2
go_router: ^17.5.0
```

The local history module adds:

```yaml
hive: ^2.2.3
path_provider: ^2.1.6
```

The illustrated room renderer adds:

```yaml
flutter_svg: ^2.3.0
vector_graphics: 1.2.4
gal: 2.3.2
```

The camera/photo module adds these constraints (resolved versions are in `pubspec.lock`):

```yaml
camera: ^0.12.0+2
image_picker: ^1.2.4
image: ^4.12.0
permission_handler: ^12.0.1 # resolves 12.0.3; Android implementation 13.0.1
share_plus: ^13.3.1
```

The permission-handler 12 line intentionally retains the current AGP 8 toolchain: version 13 resolved an Android implementation that assumes AGP 9/Kotlin built-in support and failed compilation. Android AGP is 8.12.1 (Gradle 8.14, Kotlin 2.2.20, Java 17) for share_plus compatibility. Minimum Android SDK remains 24. Android manifest declares CAMERA with optional camera hardware and removes inherited audio/read permissions. Illustrated-room Gallery export has only `WRITE_EXTERNAL_STORAGE` capped at API 29; it does not declare `READ_MEDIA_*`, `MANAGE_EXTERNAL_STORAGE` or a legacy-storage application flag. No microphone is used. iOS targets 13.0, retains the photo-selection read usage description, adds `NSPhotoLibraryAddUsageDescription`, and CocoaPods enables only `PERMISSION_CAMERA=1`. Photo selection uses image_picker's system access with `requestFullMetadata:false` and no broad photo-library read permission.

Fonts, data, and license assets are registered in `pubspec.yaml`. There is no code generation or runtime network requirement. Restart an already-running app after adding native plugins; hot reload alone cannot register them.

## Verify and preview

```sh
COLOR_LAB_FLUTTER_ROOT=/path/to/flutter
"$COLOR_LAB_FLUTTER_ROOT/bin/cache/dart-sdk/bin/dart" --suppress-analytics format --output=none --set-exit-if-changed lib test tool
/usr/bin/sandbox-exec -f tool/deny-native-compilers.sb "$COLOR_LAB_FLUTTER_ROOT/bin/flutter" analyze --no-pub
/usr/bin/sandbox-exec -f tool/deny-native-compilers.sb "$COLOR_LAB_FLUTTER_ROOT/bin/flutter" test --no-pub --reporter expanded
/usr/bin/sandbox-exec -f tool/deny-native-compilers.sb "$COLOR_LAB_FLUTTER_ROOT/bin/flutter" test tool/render_previews.dart --no-pub --reporter expanded
/usr/bin/sandbox-exec -f tool/deny-native-compilers.sb "$COLOR_LAB_FLUTTER_ROOT/bin/flutter" test tool/render_illustrated_room_previews.dart --no-pub --reporter expanded
/usr/bin/sandbox-exec -f tool/deny-native-compilers.sb "$COLOR_LAB_FLUTTER_ROOT/bin/cache/dart-sdk/bin/dartvm" tool/run_room_model_smoke.dart --flutter-root "$COLOR_LAB_FLUTTER_ROOT"
```

These guarded host commands require macOS `sandbox-exec` and already available dependencies/prebuilt native test assets. They allow Dart bytecode and existing prebuilts while denying native compiler/build executables. A fresh clone lacking cached native hook assets may fail closed; this does not authorize bypassing the guard, deleting caches, fetching dependencies or compiling native support libraries during this verification workflow. See [the execution guard](docs/superpowers/plans/room-verification-guard.md). The smoke wrapper deliberately uses direct `dartvm`, avoiding Dartdev build hooks.

The main preview command regenerates the existing capture suite, including Room empty/import/analysis, recorded reference layers, refinement and responsive editor states. The illustrated-room command writes exactly 27 deterministic real-font samples: six grayscale artworks, six recommended-color artworks, six stress-color artworks, gallery phone/tablet, editor phone rail closed/open/focus/whole-room, 640×360 landscape, 1024×768 tablet and one real recommended Study 2400×1600 PNG export. Its manifest records sorted per-room SVG complexity metrics. The source test harness remains native-channel-free and uses the guarded no-native-compiler flow above, a fixed clock, an in-memory repository and UI export fakes; the dedicated export sample uses the real SVG encoder. It never opens a native Gallery channel or writes user documents. Room mask previews use real `preparePhoto` output and recorded segmentation bytes at the service boundary but do not execute native inference or establish hardware compatibility. PNGs are written only to `build/previews/`. See the [polished-room evidence](docs/superpowers/plans/2026-10-25-polished-3d-illustrated-rooms-evidence.md) for measured metrics, visual review and verification limits.

Foundation verification on 2026-10-21: all 47 automated tests passed, static analysis had no issues, all eight screen previews rendered, and the Android debug APK built successfully. iOS device execution has not been verified. The Foundation snapshot remains available at `dist/color-lab-foundation-2026-10-21.zip`; the new module's handoff archive is `dist/color-lab-history-2026-10-21.zip`.

History verification on 2026-10-21: **96 automated tests passed**, including real-file persistence and injected flush failures, factory/directory retry, disposal, and the manual-entry → Save → Palette flow. That milestone's APK and eight previews also passed.

Camera/photo milestone verification on 2026-10-21: **186 automated tests passed**, whole-project analysis reported no issues, all 70 Dart files passed the formatting check, 14 light/dark previews rendered, and the debug APK built. APK permissions were inspected with `aapt`: CAMERA present; RECORD_AUDIO and legacy read/write storage absent. Independent review findings and the subsequent permission-dialog regression were addressed.

Onboarding/settings verification on 2026-10-21: **246 automated tests passed**, whole-project analysis reported no issues, all 87 Dart files passed the formatting check, 22 light/dark previews rendered, and the updated debug APK built. Actual-disk restarts restored completion and Dark/System preferences through fresh ProviderContainers. Independent review and scoped re-review approved that module after rendered-contrast and root-modal fixes. No new dependencies or native permission declarations were needed. Native screen-reader/predictive-back and physical camera/iOS verification remain device checks.

Mixer verification on 2026-10-21: **334 automated tests passed**, including 40 mixing-math, 24 draft/controller, 14 picker and 10 screen tests. Whole-project analysis reported no issues and all 97 Dart files passed the formatting check. The renderer passed both theme tests and produced 32 previews, including mixer ingredients/pinned result and narrow 2x picker layouts. The Android debug APK built successfully. Independent review results are recorded in the mixer ledger.

Formula verification on 2026-10-21: **387 automated tests passed**, including 29 new pure-formula, 11 isolate/provider and 13 UI integration tests. Tests include independent LAB/displayed-error fixtures, full-grid optimality, real VM worker execution, out-of-order completions, actual target picking, selected-result save/details/Room, same-route entry and enlarged text/reduced motion. Final review caught a camera navigation-lifetime regression; an awaited formula route now keeps sampling paused while formula is open and resumes with fresh samples after Back. A behavioral RED→GREEN camera round trip and successful-result→pending/refresh regressions cover the fix. Final checks: analysis clean, all 106 Dart files formatted, 42 previews rendered and debug APK rebuilt. Review/archive evidence is in the formula ledger. Physical-device/iOS/native accessibility execution remains unverified.

Harmonies verification on 2026-10-21: **481 automated tests passed** (94 new: 20 engine/controller, 30 snapshot/storage/provider, 22 raster/semantic wheel and 22 UI integration tests). Tests include real-file close/reopen through fresh containers and the actual save dialog, failed flush/read/no-op barriers, delayed-save capture, exact snapshot display, camera round trips and repeated library swatch navigation. Independent UI review findings were reproduced before fixes and verified after: dialog label contrast/48dp targets and returning to the existing editor. Analysis is clean, all 126 Dart files pass formatting, 68 real-font previews render and the debug APK builds. Final review/archive evidence is recorded in the harmonies ledger. Physical-device/iOS/native accessibility execution remains unverified.

Matching game verification on 2026-10-21: **525 automated tests passed** (44 new: 28 pure scoring/target/domain/controller and 16 full-app matching tests). Coverage includes independent CIE76/rounded-score fixtures, bounded target generation, neutral-coordinate restoration, frozen attempts/phase guards, hidden target values, five-round summary/replay, confirmed/system-Back restart, independent drafts and storage isolation. Test-first checks added the pinned comparison and caught an offscreen summary/replay entry: those transitions now reset the viewport while slider, theme and submission changes retain position. Whole-module review and the scoped viewport fix review approved. Post-fix checks: clean analysis, all 134 Dart files formatted, 82 real-font previews and rebuilt debug APK. Review/archive evidence is in the matching ledger. Physical-device/iOS/native accessibility execution remains unverified.

Vision activity verification on 2026-10-21: **569 automated tests passed** (44 new: 23 pure domain/controller, seven actual raster/semantics and 14 full-app tests). Coverage includes independent glyph/color fixtures, seed-only geometry, null versus zero, stale callbacks, retained independent drafts, actual plate pixels across theme/advance, confirmed restart, six frozen responses and visible viewport entry. Analysis is clean, all 146 Dart files pass formatting, and 104 real-font previews render, including 22 new vision captures. Task-scoped reviews approved without findings; final review/archive evidence is recorded in the vision ledger. **No APK/native build or install was run**; the earlier APK and eight prior source ZIP hashes are unchanged. Device/iOS/native accessibility and clinical validity are not established.

## Vision activity delivery changes

```text
+ lib/features/color_test/domain/{vision_plate,vision_dot_pattern,vision_session}.dart
+ lib/features/color_test/application/vision_controller.dart
+ lib/features/color_test/presentation/{vision_plate_view,vision_screen}.dart
~ lib/features/lab/presentation/lab_screen.dart, lib/routing/app_router.dart
+ test/features/color_test/{domain,application,presentation}/vision*_test.dart
~ tool/render_previews.dart, README.md
+ docs/superpowers/specs/2026-10-21-vision-plates-design.md
+ docs/superpowers/plans/2026-10-21-vision-plates*.md and vision task/review reports
```

No `pubspec.yaml` additions, platform changes, code generation or migration. No APK build. Existing Run commands need no additional setup; the Verify commands above intentionally omit native packaging for this module.

## Matching game delivery changes

```text
+ lib/core/color/color_matching.dart
~ lib/core/color/color_engine.dart
+ lib/features/color_test/domain/matching_game.dart
+ lib/features/color_test/application/matching_game_controller.dart
+ lib/features/color_test/presentation/matching_screen.dart
~ lib/features/lab/presentation/lab_screen.dart, lib/routing/app_router.dart
+ test/core/color/color_matching_test.dart
+ test/features/color_test/{domain,application,presentation}/
~ tool/render_previews.dart, README.md
+ docs/superpowers/specs/2026-10-21-color-matching-design.md
+ docs/superpowers/plans/2026-10-21-color-matching*.md and matching task/review reports
```

No `pubspec.yaml` additions, native configuration, code generation or database migration. Earlier cumulative source ZIPs and user/device data are retained. Use the existing Run/Verify commands; no extra setup step is needed.

## Harmonies delivery changes

```text
+ lib/core/color/color_harmonies.dart
~ lib/core/color/color_engine.dart
+ lib/features/harmonies/application/harmony_controller.dart
+ lib/features/harmonies/presentation/{harmonies_screen,harmony_wheel,save_palette_dialog}.dart
+ lib/features/palette/domain/{saved_palette,saved_palette_repository}.dart
+ lib/features/palette/application/saved_palettes_providers.dart
+ lib/data/db/hive_palette_repository.dart
+ lib/features/palette/presentation/{saved_palettes_section,saved_palettes_screen}.dart
~ lib/features/palette/presentation/palette_screen.dart
~ lib/features/lab/presentation/lab_screen.dart
~ lib/features/picker/presentation/color_explorer.dart, lib/routing/app_router.dart
+ test/core/color/color_harmonies_test.dart, test/features/harmonies/
+ test/features/palette/{domain,application}/, test/data/db/hive_palette*_test.dart
+ test/support/in_memory_saved_palette_repository.dart
~ tool/render_previews.dart, README.md
+ docs/superpowers/specs/2026-10-21-harmonies-design.md
+ docs/superpowers/plans/2026-10-21-harmonies*.md and harmony task/review reports
```

Earlier cumulative source ZIPs, user/device data, packages, platform settings and existing database schemas are retained. No extra setup step is needed.

## Formula delivery changes

```text
+ lib/core/color/color_formula.dart
~ lib/core/color/color_engine.dart
+ lib/features/formula/application/{color_formula_service,formula_providers}.dart
+ lib/features/formula/presentation/{formula_screen,formula_recipe_card}.dart
~ lib/features/lab/presentation/lab_screen.dart
~ lib/features/picker/presentation/color_explorer.dart
~ lib/routing/app_router.dart
+ test/core/color/color_formula_test.dart
+ test/features/formula/application/{color_formula_service,formula_providers}_test.dart
+ test/features/formula/presentation/formula_integration_test.dart
~ tool/render_previews.dart, README.md
+ docs/superpowers/specs/2026-10-21-color-formula-design.md
+ docs/superpowers/plans/2026-10-21-color-formula*.md and formula task/review reports
```

No `pubspec.yaml` additions, code generation, native configuration or database migration. Earlier cumulative source ZIPs are retained. Use the Run/Verify commands above; no extra setup step is needed.

## Mixer delivery changes

```text
+ lib/core/color/color_mixer.dart
~ lib/core/color/color_engine.dart
+ lib/features/mixer/domain/mixer_state.dart
+ lib/features/mixer/application/mixer_controller.dart
+ lib/features/mixer/presentation/{mixer_screen,mixer_color_picker}.dart
~ lib/features/lab/presentation/lab_screen.dart, lib/routing/app_router.dart
+ test/core/color/color_mixer_test.dart
+ test/features/mixer/{domain,application,presentation}/
~ tool/render_previews.dart, README.md
+ docs/superpowers/specs/2026-10-21-color-mixer-design.md
+ docs/superpowers/plans/2026-10-21-color-mixer*.md and mixer task/review reports
```

No `pubspec.yaml`, native configuration or history schema changes. Earlier cumulative source ZIPs are retained.

## Onboarding/settings delivery changes

No `pubspec.yaml` additions, code generation or native platform changes are needed. Current packages and minimum OS versions remain unchanged.

```text
+ lib/features/onboarding/presentation/{onboarding_screen,onboarding_art}.dart
+ lib/features/settings/domain/{app_preferences,app_preferences_repository}.dart
+ lib/features/settings/application/app_preferences_providers.dart
~ lib/features/settings/application/theme_mode_provider.dart
+ lib/features/settings/presentation/{preferences_startup_screen,settings_sheet}.dart
+ lib/data/db/hive_app_preferences_repository.dart
~ lib/app.dart, lib/routing/app_router.dart
~ lib/features/shell/presentation/studio_page.dart
+ test/features/onboarding/{onboarding_screen,onboarding_contrast}_test.dart
+ test/features/settings/{domain,application}/
+ test/features/settings/{onboarding_settings_integration,preferences_disk_restart,settings_modal_contrast}_test.dart
+ test/data/db/hive_app_preferences_repository_test.dart
+ test/support/in_memory_app_preferences_repository.dart
~ test/widget_test.dart, test/features/picker/{capture_integration,color_details_actions}_test.dart
~ tool/render_previews.dart, README.md
+ docs/superpowers/specs/2026-10-21-onboarding-settings-design.md
+ docs/superpowers/plans/2026-10-21-onboarding-settings*.md
+ docs/superpowers/plans/{preferences-storage-report,onboarding-ui-report,onboarding-final-fix-report,onboarding-independent-review}.md
```

## Camera/photo delivery changes

```text
+ lib/core/image/photo_processing.dart
+ lib/core/utils/camera_sampling.dart
+ lib/core/color/color_presentation.dart
+ lib/features/picker/domain/{camera_frame,prepared_photo,photo_viewport}.dart
+ lib/features/picker/application/{camera_session,photo_processor,photo_picker_service,color_share_service}.dart
+ lib/features/picker/presentation/{camera_picker_screen,photo_picker_screen}.dart
~ lib/features/picker/presentation/{capture_screen,color_explorer}.dart
+ lib/features/room_studio/application/room_color_provider.dart
~ lib/features/room_studio/presentation/room_screen.dart
~ lib/core/widgets/structure.dart
~ lib/routing/app_router.dart
+ test/core/{camera,image}/
+ test/core/color/color_presentation_test.dart
+ test/features/picker/ (backend, processing, gestures, routing and detail actions)
~ tool/render_previews.dart
~ android/settings.gradle.kts, android/app/src/main/AndroidManifest.xml
~ ios/Runner/Info.plist, ios/Podfile
~ pubspec.yaml, pubspec.lock, README.md
+ docs/superpowers/plans/2026-10-21-capture-*.md and task/review reports
```

See the [capture plan](docs/superpowers/plans/2026-10-21-capture-photo.md) and [verification ledger](docs/superpowers/plans/2026-10-21-capture-progress.md). That milestone's source snapshot remains at `dist/color-lab-capture-2026-10-21.zip`; earlier archives are retained. iOS compilation/device execution, physical camera calibration/preview alignment, real gallery process-death recovery and device memory profiling remain unverified. An Android emulator install was attempted without clearing data, but its storage was full; no emulator/user files were deleted. A connected physical phone was not modified.

Primary API references used: [camera](https://pub.dev/packages/camera), [image_picker](https://pub.dev/packages/image_picker), [permission_handler12](https://pub.dev/packages/permission_handler/versions/12.0.1), [share_plus](https://pub.dev/packages/share_plus).

## History delivery changes

`+` marks new files; `~` marks changed files relative to Foundation. No manual platform configuration or code generation is needed for this module.

```text
+ lib/data/db/hive_color_history_repository.dart
+ lib/features/history/domain/{saved_color,color_history_repository}.dart
+ lib/features/history/application/history_providers.dart
+ lib/features/history/presentation/{color_history_section,save_color_actions}.dart
~ lib/features/palette/presentation/palette_screen.dart
~ lib/features/picker/presentation/color_explorer.dart
~ lib/features/lab/presentation/lab_screen.dart
~ lib/features/room_studio/presentation/room_screen.dart
+ test/data/db/{hive_color_history_repository,hive_color_history_durability}_test.dart
+ test/features/history/domain/saved_color_test.dart
+ test/features/history/application/history_providers_test.dart
+ test/features/history/presentation/color_history_section_test.dart
+ test/features/history/save_color_actions_test.dart
+ test/support/in_memory_color_history_repository.dart
~ test/widget_test.dart
~ tool/render_previews.dart
~ pubspec.yaml, pubspec.lock, README.md
+ docs/superpowers/plans/2026-10-21-color-history.md
+ docs/superpowers/plans/2026-10-21-history-progress.md
+ docs/superpowers/plans/{history-storage-report,history-ui-report}.md
```

## Source map

Current cumulative app structure; generated platform files not listed are managed by Flutter.

```text
lib/
  main.dart                       Entry, ProviderScope, asset-license registration
  app.dart                        MaterialApp.router and reactive theme
  routing/app_router.dart         Guarded tabs, tour/startup, camera/photo and Lab tools
  core/
    theme/                        Tokens, theme extension, Material 3 themes
    widgets/                      Fourteen reusable adaptive widgets
    color/                        Models, conversions, naming, mixing, formulas, harmonies, k-means
  data/assets/                    Cached asynchronous color-name asset adapter
  data/db/                        Durable serialized Hive history/preferences/palette repositories
  features/
    shell/presentation/           Navigation, shared studio layout, appearance menu
    onboarding/presentation/      Three-slide tour and procedural illustrations
    picker/domain/                Serializable camera frames, prepared photos, viewport math
    picker/application/           Camera session, photo acquisition/processing, system share
    picker/presentation/          Capture, camera/photo pickers, HEX input, detail sheet
    palette/{domain,application}/ Immutable palette snapshots, durable library/controller
    palette/presentation/         Saved colors, whole palettes and Studio inspiration
    history/domain/               Immutable SavedColor, sources, repository contract
    history/application/          Loaded history, serialized edits, search/filter state
    history/presentation/         Saved library, favorite/delete/save actions
    lab/presentation/             HSL color exploration and mixer entry
    mixer/{domain,application}/   Immutable weighted draft and session controller
    mixer/presentation/           LAB/RGB comparison and manual/saved ingredient picker
    formula/application/          Isolate search, session target and keyed async result
    formula/presentation/         Approximate recipe, error and reference base shades
    harmonies/application/        Retained independent base/mode session draft
    harmonies/presentation/       Six-mode wheel, actual swatches and named-save dialog
    color_test/domain/            Immutable matching game, original dots and vision responses
    color_test/application/       Injectable generators and independent retained sessions
    color_test/presentation/      Matching, cached dot plates and non-diagnostic response summary
    room_studio/                  Six-room SVG color gallery, saved designs/Gallery export,
                                  photo masks, worker inference, refinement and recolor editor
    settings/domain/              Versioned appearance/onboarding preferences
    settings/application/         Durable preferences, theme, lifecycle/retry
    settings/presentation/        Startup recovery and Appearance/replay/privacy sheet
assets/
  data/color_names.json
  fonts/                          Two local variable TTF fonts
  licenses/                       Original MIT/OFL and Room model license/provenance notices
  models/                         Pinned offline MOSAIC model and checked descriptor
  rooms/                          Six original layered SVG room illustrations
test/
  core/color/                     Reference conversions, mixing and clustering edge cases
  core/theme/                     Theme application and text contrast
  core/widgets/                   Controls, semantics, clipboard, reduced motion
  data/                           Fallbacks, caching, and actual bundled dataset
    db/                           Real-file reopen, corruption and flush-failure tests
  features/history/               Model, repository, controller, and library/action tests
  features/mixer/                 Numeric integration, draft, picker and navigation tests
  features/formula/               Real-isolate, async-provider and formula UI integration
  features/harmonies/             Literal fixtures, draft, raster wheel and route/save tests
  features/color_test/            Matching, original dot/mask fixtures, retained responses,
                                  actual painter pixels/semantics and full-app flows
  features/palette/               Snapshot schema, controller retry/disposal and disk restart
  features/room_studio/           SVG mapping, gallery/editor, persistence and export tests
  support/                        Test-local repository boundary for UI isolation
  fixtures/room/                  CC0 photo, independent model input and actual recorded masks
  widget_test.dart                Navigation, HEX workflow, appearance, tab state,
                                  narrow-screen and large-text layout
tool/render_previews.dart         Real-font visual inspection utility
tool/render_illustrated_room_previews.dart
                                  Deterministic six-room artwork and responsive UI previews
tool/deny-native-compilers.sb    Fail-closed host verification compiler guard
tool/run_room_model_smoke.dart   Direct-VM production inference verification wrapper
android/app/build.gradle.kts      Minimum SDK 24
pubspec.yaml                     Packages, bundled data, fonts and license assets
pubspec.lock                     Resolved dependency versions
docs/asset-sources.md             Pinned asset sources, licenses, checksums
docs/superpowers/                 Approved design, plan, progress and review reports
README.md
```

Algorithm input contracts and rounding conventions are documented on the public APIs in `lib/core/color/`. Pure palette extraction accepts sampled RGB; the photo worker owns downscaling and isolate dispatch. RGB channels are integers 0–255, HSL/HSV saturation and lightness/value use 0–1, hue uses degrees, CMYK uses 0–1, and LAB uses D65. Alpha HEX is deliberately rejected.

See [asset sources](docs/asset-sources.md) for pinned upstream versions and redistribution notices. Bundled notices are also accessible through Appearance → About Color Lab & licenses in a normal application launch.
