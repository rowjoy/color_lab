### Task 10: Independent gates previews and source only handoff

**Files:** `tool/render_previews.dart`, `tool/deny-native-compilers.sb`, `test/fixtures/room/{reference_masks.bin,reference_masks.json}`, `docs/asset-sources.md`, `README.md`, current Room spec/plan/progress/reports, `docs/superpowers/plans/room-source-archive-recipe.rb`, `dist/color-lab-room-masks-2026-10-22.zip`.

**Consumes:** All frozen interfaces above and real model evidence; no new product API.

**Execution corrections:** Read `room-verification-guard.md`; every Flutter test/
preview command retains its compiler-deny prefix, and smoke uses direct `dartvm`,
not the historical `dart run` example below. Retain the identical profile under
`tool/deny-native-compilers.sb` for portable final commands. The user confirmed
independently running/building the app: current APK SHA-256 is
`00896beade2a82a2f99908e203b1f4c56a07daa8ef678dcd7f13d85a220d2ae7`,
timestamp2026-10-22 02:24:15+0600. Preserve this newer user artifact, disclose its
difference from the historical baseline below; never overwrite it or claim the
old hash still matches. The nine previous ZIPs still match their baselines.

Latest-observation correction: the preceding execution text is historical.
Both APK copies now hash
`eb36f749379d33e82644e6c61861647ccb88c685479ff780bd3bd2959fa0a3ae`,
162,563,223 bytes, modified2026-10-22 10:37:35+0600; the origin of this later
change is not attributed. Preserve these currently observed files untouched,
not the obsolete00896 bytes or the original1986 baseline. This workflow did
not build or touch them. Nine prior ZIP hashes still match; Android24/iOS13
configs are byte-identical to original baseline. The historical checklist below
is interpreted with this correction and the current final-verification record.

- [x] **Extend diagnostic captures first.** Preserve the 104 existing stems. Add Room empty/import progress, actual reference-mask layers, Add/Erase, undo/restore and pending/error states, both themes; narrow 360×800/2× text/reduced-motion editor/dialog cases. Use real controller/viewport and a static output recorded from the verified model for repeatable preview fixtures, not hand-made masks presented as model execution. Retain actual Task5 service bytes as `test/fixtures/room/reference_masks.bin` (SHA-256 `5ab660689348ba538d622d681742d365d50ce8f08ee8bb3a8712bfa733c840ba`,1280×853), plus portable identity/provenance/count/checksum metadata in `reference_masks.json`; no absolute temporary dependency in rendering. Do not regenerate masks from a fake or alter Task1's independent fixtures. Record fixture attribution in asset sources. State that previews are not native inference or hardware evidence.
- [x] **Run independent gates.** Each task report supplies exact brief/files/RED/GREEN/exits; review task source/test deltas, fix through its owner and re-review the fix. One most-capable whole-module review follows the scoped gates. Main executor performs the plan/spec coverage and signature check itself, not via delegated plan self-review.
- [x] **Run fresh final verification.** `dart run tool/run_room_model_smoke.dart --flutter-root /Users/jamirulislam/Applications/flutter`, `flutter test --no-pub --reporter expanded`, `flutter analyze --no-pub`, `dart format --output=none --set-exit-if-changed lib test tool`, and `flutter test tool/render_previews.dart --no-pub --reporter expanded` all exit0. Inspect actual reference masks/overlays and enlarged layouts. No APK/native build/install/clean command. Record counts only after observing output;569 was the preceding milestone, not this module's result.
- [x] **Write truthful handoff documentation.** README distinguishes real AI, manual refinement, derived mask overlays and subsequent recolor/project/export work; records working-image resolution, session-only photo/edits, operational recovery intent, runtime version/notice requirements and device limits. Preserve and recheck the old APK SHA-256 `1986b60e39c94af8bbc2bacb71b14dc7cf427899f3476ff60bbb581d56b12b2c` and nine old ZIP hashes. Keep both platform floors unchanged. Model/fixture provenance and checksums must appear in asset sources; no runtime model URL.
- [x] **Package and validate the cumulative source ZIP.** Include sources/assets/test fixtures/tests/tools/docs/native source/pubspec/lock/licenses/README/metadata. Exclude APK/AAB, build output, native binaries used only by host checks, local.properties, caches, Pods/symlinks, ephemeral/Xcode environment/xcuserdata, IDE files and previous ZIPs. `unzip -tq` must pass; compare required archived files with workspace bytes and scan for duplicates/absolute/traversal entries. Refresh final plan/progress/report edits into the ZIP and recheck integrity before delivery. Do not link the old APK as this delivery.

## Self review and handoff

Main-agent self-review maps the approved design as follows:

| Design requirement | Owning tasks |
| --- | --- |
| Real model, provenance, runtime/platform floors and metadata gate | 1, 5 |
| Photo limits, explicit camera action, durable intent and safe recovery | 3, 4, 9 |
| Aligned preprocessing, protected classes, exclusive layers and feather | 2, 5, 8 |
| Candidate/committed drafts, retention and stale completion guards | 7, 9 |
| AI-before-manual, stroke geometry, ownership and bounded exact undo | 5, 6, 7, 8, 9 |
| Accessible UI, independent tests/review and source-only delivery | 8, 9, 10 |

Cross-task signatures and all five Review Focus cases are checked against their
owning test steps. The first gate does not depend on the later preprocessor:
it uses a separately recorded reference tensor. Worker tests do not pretend a
copied isolate fake is observable from the UI. The binary's unknown numeric
metadata remains an explicit inspection gate, not an invented constant.
No spec coverage gap remains in the plan. This is planning evidence, not passing
product-test or native-runtime evidence. Execution status and evidence are tracked
in `2026-10-22-room-auto-masking-progress.md`; checklists change only after the
corresponding work is verified.

Recommended method: **Subagent-driven**, because acquisition recovery, native
worker lifecycle and immutable edit revisions cross independent boundaries
where scoped fresh reviews are valuable. Native execution remains a valid
alternative, with one final independent review. The user accepted the recommended
method before implementation began.
