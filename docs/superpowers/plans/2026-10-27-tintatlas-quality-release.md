# TintAtlas Quality and Core Release Preparation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the completed ad-free TintAtlas feature set into an accessible, localized, privacy-checked, measured, and independently verifiable core release candidate without publishing it.

**Architecture:** Treat quality evidence as versioned input: a route catalogue drives automated layout, semantics, localization, and failure checks, while a typed evidence ledger validates the manual device and usability records that automation cannot supply. Central security/resource policies constrain every local file and image boundary; per-platform release gates remain independent and the candidate remains ad-free until this plan closes.

**Tech Stack:** Flutter/Dart 3.11, Material 3, generated Flutter localization, Riverpod, GoRouter, Hive/file repositories from earlier plans, Flutter unit/widget/integration tests, Android Gradle, Xcode configuration, and repository Dart verification tools.

**Spec:** `docs/superpowers/specs/2026-10-27-tintatlas-full-product-design.md`

## Global Constraints

- Read `2026-10-27-tintatlas-master.md` and every completed feature plan before this plan; do not close a quality requirement by weakening an earlier feature contract.
- Preserve the Dart package name and private data directory literal `color_lab`, existing Hive box names, model URLs/hashes, and all five `GameId` storage IDs.
- Width classes remain Compact `<600`, Medium `600–839`, Expanded `840–1199`, and Large `>=1200`; required automated viewports are `320×568`, `568×320`, `600×960`, `840×1180`, `1024×768`, and `1440×900` at 100% and 200% text where applicable.
- Android API 24 and iOS 13 remain the provisional floors; changing either requires measured evidence and explicit user approval.
- Android and iOS gates are independent, but both consume the same Dart/schema/localization/privacy tests; an Android result never satisfies an iOS device/archive gate.
- English is the first complete locale. Later public languages require audience evidence and human linguistic review; machine-only translated copy cannot pass a release gate.
- Photos, masks, drawings, palettes, and content-derived labels remain local and are never sent to advertising, analytics, crash, or support services.
- This plan adds no advertising SDK, production ad identifier, analytics/crash SDK, account, upload, or public-release action.
- Signing credentials and store accounts remain user-owned, untracked inputs; absence blocks that platform candidate rather than falling back to debug signing.
- Do not push, publish, upload, alter store state, or include the user-owned `lib/main.dart` edit in a task commit without explicit authorization.

## Review Focus

- A route that opens only with saved state, a game launch, a model error, or a corrupt record still appears in the catalogue and can be audited without real user data.
- At 200% text on `320×568` or with the keyboard visible, the primary action remains reachable by scrolling and no modal traps focus.
- Malicious IDs, oversized images, truncated files, symlinks, and traversal strings cannot escape app-private roots or trigger unbounded decoding/allocation.
- A killed or failed write/export/model operation preserves the last acknowledged state, ignores stale completion, and gives a localized recovery action.
- Manual device/usability evidence cannot be marked passed without the named hardware, assistive technology, participant result, artifact checksum, and reviewer recorded.

---

### Task 1: Freeze the route, quality, and evidence contracts

**Files:**
- Create: `lib/core/release/release_evidence.dart`
- Create: `test/support/app_route_catalog.dart`
- Create: `tool/check_release_evidence.dart`
- Create: `test/tool/check_release_evidence_test.dart`
- Create: `docs/release/route-quality-matrix.md`
- Modify: `docs/release/performance-budgets.md`
- Create: `docs/release/quality-evidence.schema.json`
- Create: `docs/release/evidence/core-candidate.json`
- Modify: `docs/release/verification-ledger.md`

**Interfaces:**
- Consumes: the final route names/paths from `lib/routing/app_router.dart`, feature fixtures from Plans 02–07, and the support contract from Plan 01.
- Produces: `AppRouteCase`, `ReleaseEvidenceEntry`, `ReleasePlatform`, `ReleaseGateStatus`, and a command that rejects fabricated, stale, or incomplete manual evidence.
- Spec coverage: evidence foundation for A11Y-01–05, L10N-01–03, DEVICE-01–04, UXQA-01, QUALITY-01–07, and REL-01–09.

```dart
enum ReleasePlatform { shared, android, ios }
enum ReleaseGateStatus { passed, failed, blocked, notApplicable }
enum ReleaseEvidenceKind { automated, manual, external }

final class ReleaseEvidenceEntry {
  const ReleaseEvidenceEntry({
    required this.gateId,
    required this.platform,
    required this.kind,
    required this.status,
    required this.candidateCommit,
    required this.recordedAt,
    required this.buildId,
    required this.artifactSha256,
    required this.deviceId,
    required this.reviewer,
    required this.note,
  });
  final String gateId;
  final ReleasePlatform platform;
  final ReleaseEvidenceKind kind;
  final ReleaseGateStatus status;
  final String candidateCommit;
  final DateTime recordedAt;
  final String? buildId;
  final String? artifactSha256;
  final String? deviceId;
  final String? reviewer;
  final String note;
}

final class AppRouteCase {
  const AppRouteCase({
    required this.id,
    required this.location,
    required this.fixture,
    required this.primaryActionKey,
  });
  final String id;
  final String location;
  final Future<void> Function(WidgetTester tester) fixture;
  final Key primaryActionKey;
}
```

- [ ] **Step 1: Write `check_release_evidence_test.dart`.** Assert that duplicate gate IDs, unknown platforms/statuses, missing device/build/artifact fields, a `passed` manual gate without a reviewer, and evidence older than the candidate commit all return a non-zero validation result.
- [ ] **Step 2: Run `flutter test test/tool/check_release_evidence_test.dart --reporter expanded`.** Expected: FAIL because the evidence parser and validator do not exist.
- [ ] **Step 3: Implement the evidence types, JSON schema, CLI validator, and complete `appRouteCatalog`.** Catalogue every router leaf, including fixture-backed saved work, active game launch, permission/model failures, corrupt-record warning, unknown route, and empty states; do not silently exclude hard-to-construct routes.
- [ ] **Step 4: Record exact numeric budgets.** Copy the approved Phase 0 size/startup/model/storage/memory/latency limits into `performance-budgets.md`; if any budget was never approved, record that gate as `blocked` with owner and required measurement instead of inventing a threshold.
- [ ] **Step 5: Run `flutter test test/tool/check_release_evidence_test.dart` and `dart run tool/check_release_evidence.dart docs/release/evidence/core-candidate.json --allow-blocked`.** Expected: tests PASS and the pre-candidate template validates while preserving blocked external gates.
- [ ] **Step 6: Commit.** `git commit -m "test: define TintAtlas release evidence contracts"`.

### Task 2: Enforce complete localization and locale-safe layout

**Files:**
- Create: `tool/check_user_visible_strings.dart`
- Create: `tool/user_visible_string_allowlist.json`
- Create: `test/tool/check_user_visible_strings_test.dart`
- Create: `test/l10n/app_localizations_contract_test.dart`
- Create: `test/l10n/locale_layout_matrix_test.dart`
- Create: `test/support/long_string_test_delegate.dart`
- Modify: `lib/l10n/app_en.arb`
- Modify only after recording an exact failing path in `docs/release/route-quality-matrix.md`: the presentation file that owns that literal; add that path to the task evidence before editing and reject unrelated bulk rewrites
- Modify: `docs/release/route-quality-matrix.md`

**Interfaces:**
- Consumes: generated `AppLocalizations`, `BuildContext.l10n`, and `appRouteCatalog`.
- Produces: deterministic source scanning plus long-string and RTL route tests; the allowlist accepts only non-user-visible keys, debug diagnostics, color hex values, and legal identifiers with a reason per entry.
- Spec coverage: L10N-01–03 and the localization portions of SHELL-08/SHELL-13.

- [ ] **Step 1: Write scanner RED tests.** Fixtures must reject visible `Text('literal')`, semantic labels, tooltip/snackbar/dialog literals, concatenated grammar, and unlabeled allowlist entries while accepting localization keys, route paths, asset paths, debug-only diagnostics, and `#RRGGBB`.
- [ ] **Step 2: Run `flutter test test/tool/check_user_visible_strings_test.dart test/l10n/app_localizations_contract_test.dart`.** Expected: FAIL with the unimplemented scanner and uncovered English resources.
- [ ] **Step 3: Implement the scanner and finish English resources.** Externalize every launch-route string, use generated plurals/date/number formatting, and replace grammatical concatenation with complete messages; generated Dart files are never hand-edited.
- [ ] **Step 4: Write and run `locale_layout_matrix_test.dart`.** Pump every route at `320×568`, `568×320`, and `840×1180` with 200%-length test strings under both LTR and RTL; assert zero Flutter errors, reachable `primaryActionKey`, mirrored directional controls, and scroll access above an open keyboard.
- [ ] **Step 5: Run `flutter gen-l10n`, `dart run tool/check_user_visible_strings.dart`, and `flutter test test/l10n --reporter expanded`.** Expected: all commands exit 0.
- [ ] **Step 6: Record L10N-03 as `notApplicable` for the explicitly English-only first release, with that product decision as evidence.** Before adding any later public locale, audience evidence must select it and a named human linguistic reviewer must approve it; machine-only publication is rejected.
- [ ] **Step 7: Commit.** `git commit -m "feat: complete locale-safe TintAtlas copy"`.

### Task 3: Close automated accessibility and responsive-route gaps

**Files:**
- Create: `test/accessibility/app_accessibility_matrix_test.dart`
- Create: `test/accessibility/focus_navigation_matrix_test.dart`
- Create: `test/responsive/app_responsive_matrix_test.dart`
- Create: `test/support/semantics_expectations.dart`
- Modify: `lib/core/theme/app_theme.dart`
- Modify: `lib/core/widgets/structure.dart`
- Modify: `lib/core/layout/adaptive_page.dart`
- Modify only after recording an exact failing path in `docs/release/route-quality-matrix.md`: the route/shared primitive that owns that failure; add that path to the task evidence before editing
- Modify: `docs/release/route-quality-matrix.md`

**Interfaces:**
- Consumes: `appRouteCatalog`, `MotionPreference`, semantic color roles, and the four width classes from Plan 01.
- Produces: one reusable test matrix proving focus, semantics, touch target, contrast-role, reduced-motion, viewport, safe-area, and primary-action reachability contracts.
- Spec coverage: A11Y-01–05, DEVICE-01, and the automated portion of DEVICE-04.

- [ ] **Step 1: Write matrix RED tests.** For every catalogue route assert no exceptions/overflow at all six required viewports, 200% text on compact/medium, 48×48 logical minimum interactive targets, unique actionable semantic labels, non-color identity for state, and exactly one traversable focus order with modal focus restored to its opener.
- [ ] **Step 2: Add reduced-motion/live-region cases.** Assert looping/decorative motion is absent when reduction is enabled, error/progress/completion announcements are live regions without repeated frame announcements, and Back/Escape dismisses the top modal before navigation.
- [ ] **Step 3: Run `flutter test test/accessibility test/responsive --reporter expanded`.** Expected: FAIL with a route-by-route list rather than a global timeout.
- [ ] **Step 4: Fix only the owning route/shared primitive for each recorded failure.** Use scrolling/reflow and semantic labels/patterns/text; never solve an overflow by shrinking text below the design contract or hiding an action.
- [ ] **Step 5: Re-run both suites in light, dark, high-contrast, LTR, RTL, keyboard-visible, and reduced-motion variants.** Expected: PASS; attach the route matrix output to the ledger.
- [ ] **Step 6: Commit.** `git commit -m "fix: close accessibility and adaptive layout gaps"`.

### Task 4: Constrain local files and image decoding

**Files:**
- Create: `lib/core/security/local_file_policy.dart`
- Create: `lib/core/image/image_decode_policy.dart`
- Create: `test/core/security/local_file_policy_test.dart`
- Create: `test/core/image/image_decode_policy_test.dart`
- Modify: `lib/core/image/photo_processing.dart`
- Modify: `lib/features/picker/application/photo_processor.dart`
- Modify: `lib/features/room_studio/models/room_model_store.dart`
- Modify: `lib/data/files/file_room_project_repository.dart`
- Modify: `lib/data/db/hive_room_design_repository.dart`
- Modify: `lib/data/db/hive_coloring_project_repository.dart`
- Modify: `lib/data/db/hive_learning_repository.dart`
- Create: `docs/release/threat-model.md`

**Interfaces:**
- Consumes: app-private roots from `AppStorageDirectory`, repository IDs, model descriptor limits, and the approved image-size budgets.
- Produces: `validateLocalRecordId`, `resolvePrivateChild`, and `ImageDecodePolicy.validateHeader`; every file-backed repository uses these before read/write/delete.
- Spec coverage: QUALITY-01 and the bounds portion of QUALITY-05.

```dart
String validateLocalRecordId(String value);
String resolvePrivateChild({required String root, required List<String> segments});

final class ImageDecodePolicy {
  const ImageDecodePolicy({
    required this.maxEncodedBytes,
    required this.maxWidth,
    required this.maxHeight,
    required this.maxPixels,
  });
  void validateHeader({
    required int encodedBytes,
    required int width,
    required int height,
  });
}
```

- [ ] **Step 1: Write RED tests for empty/Unicode-confusable IDs, `..`, absolute paths, separators, NUL, symlink escape, oversized/truncated dimensions, multiplication overflow, and delete requests outside the selected ownership category.** Each must fail closed without touching a sibling file.
- [ ] **Step 2: Run `flutter test test/core/security/local_file_policy_test.dart test/core/image/image_decode_policy_test.dart`.** Expected: FAIL because the policies do not exist.
- [ ] **Step 3: Implement the policies and thread them through every file-backed import, project, thumbnail, model, export-temporary, and deletion boundary.** Resolve canonical paths beneath the expected root and reject symlink components; read image headers and encoded length before full decode/allocation.
- [ ] **Step 4: Add repository regression fixtures.** A malicious/corrupt record is quarantined through `RepositorySnapshot` while healthy records remain visible and no external path is read or deleted.
- [ ] **Step 5: Run core policy, repository, picker, Room model, and project suites.** Expected: PASS with last-valid state preserved.
- [ ] **Step 6: Commit.** `git commit -m "fix: constrain local files and image resources"`.

### Task 5: Prove photo/export privacy and content provenance

**Files:**
- Create: `test/privacy/photo_metadata_privacy_test.dart`
- Create: `test/privacy/export_metadata_privacy_test.dart`
- Create: `test/privacy/network_boundary_test.dart`
- Create: `tool/check_content_rights.dart`
- Create: `test/tool/check_content_rights_test.dart`
- Create: `docs/release/content-rights-register.md`
- Create: `docs/release/privacy-data-flow.md`
- Modify: `lib/features/picker/application/photo_picker_service.dart`
- Modify: `lib/features/picker/application/photo_processor.dart`
- Modify: `lib/features/room_studio/application/room_image_export_service.dart`
- Modify: `lib/features/room_studio/application/illustrated_room_artwork_encoder.dart`
- Modify: `lib/features/coloring/application/coloring_export_service.dart`
- Modify: `docs/asset-sources.md`

**Interfaces:**
- Consumes: `requestFullMetadata: false`, processed app-private images, clean artwork renders, bundled assets/licenses, and model descriptors/checksums.
- Produces: byte-level assertions that internal/generated/shared outputs contain no EXIF/GPS/XMP/source filename; a rights checker requiring source, author/owner, license, checksum, modification note, and allowed-use status for every shipped asset.
- Spec coverage: ROOM-12 and QUALITY-02–03.

- [ ] **Step 1: Add fixtures containing GPS EXIF, camera serial, orientation, XMP, ICC, textual PNG chunks, and a source filename.** Write RED tests asserting picker requests no full metadata, processed copies normalize orientation, and every Room/Illustrated/Coloring export contains pixels plus only explicitly authored non-personal metadata.
- [ ] **Step 2: Add a fake network boundary test.** Exercise photo selection, segmentation, recolor, save, export, Learning, and Coloring while asserting no content bytes/labels reach any network client; model download may receive only the pinned model request.
- [ ] **Step 3: Run `flutter test test/privacy --reporter expanded`.** Expected: FAIL until all encoder/export paths share the clean-output policy.
- [ ] **Step 4: Implement clean encodes and complete the data-flow/right registers.** Retain no source metadata by default; document that user-triggered OS sharing happens only after the sanitized export is written.
- [ ] **Step 5: Implement and run `dart run tool/check_content_rights.dart` plus the privacy suites.** Expected: exit 0 and every bundled font, model, color-name dataset, sound, icon, room template, starter palette, and drawing has an accepted record.
- [ ] **Step 6: Commit.** `git commit -m "test: prove local photo privacy and content rights"`.

### Task 6: Bound resources and add privacy-safe support diagnostics

**Files:**
- Create: `lib/core/release/build_metadata.dart`
- Create: `lib/core/diagnostics/support_diagnostics.dart`
- Create: `lib/features/settings/presentation/support_diagnostics_screen.dart`
- Create: `test/core/diagnostics/support_diagnostics_test.dart`
- Create: `test/features/settings/support_diagnostics_screen_test.dart`
- Create: `tool/measure_core_candidate.dart`
- Create: `test/tool/measure_core_candidate_test.dart`
- Modify: `lib/features/settings/presentation/settings_sheet.dart`
- Modify: `lib/data/files/file_room_project_repository.dart`
- Modify: `lib/features/room_studio/application/room_project_session_controller.dart`
- Modify: `lib/features/room_studio/application/room_recolor_scheduler.dart`
- Modify: `lib/features/room_studio/application/illustrated_room_draft_store.dart`
- Modify: `lib/data/db/hive_coloring_project_repository.dart`
- Modify: `lib/features/coloring/application/coloring_session_controller.dart`
- Modify: `lib/data/db/hive_learning_repository.dart`
- Modify: `lib/features/learning/application/lesson_session_controller.dart`
- Modify: `lib/features/games/presentation/game_lifecycle_scope.dart`
- Modify: `docs/release/performance-budgets.md`

**Interfaces:**
- Consumes: compile-time `TINTATLAS_BUILD_VERSION`, `TINTATLAS_BUILD_NUMBER`, `TINTATLAS_COMMIT`, model status/checksum, local category byte counts, and approved budgets.
- Produces: `SupportDiagnostics.snapshot()` and `copyableText()` containing version/build/platform/model/storage/error code only—never paths, filenames, photos, masks, palette values, drawing assignments, profile names, or free text.
- Spec coverage: DEVICE-03 and QUALITY-05–07; no telemetry SDK is introduced for QUALITY-06.

```dart
final class SupportDiagnosticsSnapshot {
  const SupportDiagnosticsSnapshot({
    required this.version,
    required this.buildNumber,
    required this.platform,
    required this.modelStatuses,
    required this.storageBytesByCategory,
    required this.lastErrorCode,
  });
  final String version;
  final String buildNumber;
  final String platform;
  final Map<String, String> modelStatuses;
  final Map<LocalDataCategory, int> storageBytesByCategory;
  final String? lastErrorCode;
}

abstract interface class SupportDiagnostics {
  Future<SupportDiagnosticsSnapshot> snapshot();
  String copyableText(SupportDiagnosticsSnapshot snapshot);
}
```

- [ ] **Step 1: Write diagnostic privacy and budget-tool RED tests.** Reject snapshots/copy text containing absolute paths, user IDs/names, RGB/HEX content, observations, photo hashes, or arbitrary exception strings; fail measurements exceeding an approved budget and block unapproved budgets.
- [ ] **Step 2: Run the focused diagnostics/tool tests.** Expected: FAIL before implementations exist.
- [ ] **Step 3: Implement diagnostics and the Settings screen.** Copy is an explicit user action; the screen says data stays on device and has no automatic send action.
- [ ] **Step 4: Enforce resource bounds.** Apply approved cache/storage/history/image/worker limits, regenerate disposable thumbnails, cancel workers on provider disposal, and prove rapid navigation/recolor leaves no unbounded isolate/timer/subscription growth.
- [ ] **Step 5: Measure APK/IPA-equivalent archive size, first frame, model setup, peak memory, project growth, recolor latency, scroll jank, heat/battery protocol output on named devices.** Run `dart run tool/measure_core_candidate.dart --evidence docs/release/evidence/core-candidate.json`; expected: all approved budgets PASS and unmeasured platform gates remain BLOCKED.
- [ ] **Step 6: Commit.** `git commit -m "feat: bound resources and add safe diagnostics"`.

### Task 7: Exercise failure recovery and stale-result isolation

**Files:**
- Create: `test/support/failure_injection.dart`
- Create: `test/reliability/storage_failure_matrix_test.dart`
- Create: `test/reliability/async_failure_matrix_test.dart`
- Create: `test/reliability/offline_permission_matrix_test.dart`
- Modify: only the repository/controller/service named by a failing matrix case
- Modify: `docs/release/verification-ledger.md`

**Interfaces:**
- Consumes: repository transaction barriers, visible-versus-durable session states, cancellation/revision tokens, retry actions, and all local data categories.
- Produces: `FailurePoint`, `FailureInjector`, and matrix helpers for disk full, partial write, process-style reopen, corrupt record, network loss, permission denial, model checksum mismatch, export cancellation, and stale async completion.
- Spec coverage: QUALITY-04 plus the recovery clauses of QUALITY-01/05.

- [ ] **Step 1: Write the storage RED matrix.** Inject failure before temp write, after temp flush, before atomic pointer replace, and during cleanup for each persistent feature; assert last acknowledged work reopens, partial data is not current, healthy records stay visible, and Retry is available.
- [ ] **Step 2: Write the async RED matrix.** Complete old model/mask/recolor/export/save futures after project switch, deletion, undo, provider disposal, and route exit; assert no old result or error mutates/announces in the new context.
- [ ] **Step 3: Write the offline/permission RED matrix.** Denied camera/photo/gallery permission, offline model setup, bad checksum, cancelled export, and low storage must leave sample Rooms/Learn/Games usable with localized recovery.
- [ ] **Step 4: Run `flutter test test/reliability --reporter expanded`.** Expected: FAIL with the exact owning boundary for each unresolved case.
- [ ] **Step 5: Make minimal controller/repository fixes and rerun repository, feature, and reliability suites.** Expected: PASS; do not reset user data as an error-recovery shortcut.
- [ ] **Step 6: Commit.** `git commit -m "fix: harden TintAtlas failure recovery"`.

### Task 8: Validate real devices and moderated first use

**Files:**
- Modify: `pubspec.yaml` (add Flutter SDK `integration_test` under `dev_dependencies`)
- Create: `integration_test/app_first_use_smoke_test.dart`
- Create: `integration_test/room_project_lifecycle_test.dart`
- Create: `integration_test/saved_work_and_game_resume_test.dart`
- Create: `docs/release/device-qa-protocol.md`
- Create: `docs/release/accessibility-manual-protocol.md`
- Create: `docs/release/first-use-study-protocol.md`
- Create: `docs/release/issue-severity-policy.md`
- Modify: `docs/release/quality-evidence.schema.json`
- Modify: `docs/release/verification-ledger.md`

**Interfaces:**
- Consumes: an exact commit/build, lower-memory Android phone, current mainstream Android phone, Android tablet, and—before iOS publication—a supported iPhone and iPad; named TalkBack/VoiceOver versions and representative uncoached participants.
- Produces: per-platform evidence for camera/photo/model/export, multi-window/split view/Stage Manager/fold posture, orientation/live resize/external keyboard/display scale, accessibility navigation, thermals/battery, and first-use outcomes.
- Produces three fixture-safe native smoke flows that can run on named Android/iOS devices without embedding a participant photo or credential in the repository.
- Spec coverage: A11Y-01–05, DEVICE-02–04, and UXQA-01.

- [ ] **Step 1: Write protocols with binary observations.** Every row names device/OS/build/route/action/expected result/artifact/reviewer; screenshots or recordings must omit private photos and participant identifiers.
- [ ] **Step 2: Run uncoached first-use sessions.** Each participant must explain Rooms/Learn/Games, start a sample room, edit/save/export, explain local photo handling and optional model download, and recover from one injected error; log completion, hesitation, wrong turns, and severity without coaching.
- [ ] **Step 3: Run TalkBack on the Android candidate and VoiceOver on the iOS candidate.** Cover every route catalogue group plus canvas list alternatives, modal restoration, live regions, Back/Escape, and external keyboard/switch-equivalent operation.
- [ ] **Step 4: Run the three `integration_test/` flows plus the manual platform device matrices on each active release platform.** Android evidence can close Android only; iPhone/iPad evidence can close iOS only. Missing named hardware or participants records `blocked`, never `passed`.
- [ ] **Step 5: Fix/retest all P0 and P1 findings and any P2 that blocks the stated workflow.** Append issue IDs, before/after evidence, reviewer, and candidate commit to the ledger.
- [ ] **Step 6: Validate the evidence file.** Run `dart run tool/check_release_evidence.dart docs/release/evidence/core-candidate.json`; expected: exit 0 for the platform being prepared and no unresolved P0.
- [ ] **Step 7: Commit protocols and non-personal evidence indexes only.** `git commit -m "docs: record core candidate device and usability gates"`.

### Task 9: Prepare store/signing materials and freeze the ad-free core

**Files:**
- Create: `tool/check_release_config.dart`
- Create: `test/tool/check_release_config_test.dart`
- Create: `docs/release/privacy-policy.md`
- Create: `docs/release/data-safety.md`
- Create: `docs/release/apple-app-privacy.md`
- Create: `docs/release/store-listing.md`
- Create: `docs/release/screenshot-manifest.md`
- Create: `docs/release/rollout-and-rollback.md`
- Create: `docs/release/signing-inputs.md`
- Modify: `android/app/build.gradle.kts`
- Modify: `ios/Runner.xcodeproj/project.pbxproj`
- Modify: `ios/Flutter/Release.xcconfig`
- Modify: `.gitignore`
- Modify: `docs/release/verification-ledger.md`

**Interfaces:**
- Consumes: the approved identity decision, user-supplied Android keystore properties/Apple signing authorization, rights register, device evidence, 13+ audience proposal, and all clean shared/platform tests.
- Produces: `check_release_config.dart --mode=core --platform=<android|ios>`; room-led truthful store copy/screenshots; private credential templates; checksummed ad-free candidate artifacts and rollback instructions.
- Spec coverage: REL-01–09.

- [ ] **Step 1: Write release-config RED tests.** Require application/bundle IDs to match `identity-decision.md` exactly (reject example/old identifiers when `newListing: true`, but preserve an approved immutable published ID when `newListing: false`); reject Color Lab display text, debug release signing, absent release version/build, test/prod ad metadata in the ad-free core, untracked credential material, missing privacy/rights/audience records, and screenshots not ordered Real Room → Mask Correction → Illustrated Rooms → Learning → Coloring/Games.
- [ ] **Step 2: Run `flutter test test/tool/check_release_config_test.dart`.** Expected: FAIL before the checker and signing gates exist.
- [ ] **Step 3: Replace debug-release fallback with explicit private signing inputs.** Android release configuration fails clearly when its ignored key properties are absent; iOS archive remains blocked without the authorized team/profile. Never commit credential values.
- [ ] **Step 4: Draft store/privacy/audience materials from observed ad-free behavior.** State installation-local storage, optional on-device Room models, sanitized user-triggered exports, no account/cloud/telemetry, planned banner SDK not yet present, 13+ proposal, and platform-specific permission use; do not claim legal clearance or device support without evidence.
- [ ] **Step 5: Capture original localized screenshots from the exact candidate and checksum them in the manifest.** Use non-private fixtures and lead with Room workflows; every caption matches visible behavior.
- [ ] **Step 6: Run the pre-ad core gate.** `flutter gen-l10n`; format check; `flutter analyze`; full unit/widget/migration/failure suites; `flutter test integration_test -d <named-device>` for the active platform; `dart run tool/check_content_rights.dart`; `dart run tool/check_release_config.dart --mode=core --platform=android`; signed AAB install/upgrade/restart/offline/device test for Android, and the equivalent archive/device set when iOS is being prepared.
- [ ] **Step 7: Freeze and checksum the verified ad-free artifacts.** Record commit, lockfile hash, version/build, application ID, signing certificate fingerprint, artifact SHA-256, passed/blocked platform gates, known limits, and rollback artifact; do not publish.
- [ ] **Step 8: Obtain an independent read-only review with zero unresolved P0/P1 findings.** Append findings/resolutions to the evidence ledger.
- [ ] **Step 9: Commit.** `git commit -m "chore: freeze verified TintAtlas core candidate"`.

## Exit Gate

The ad-free core candidate has complete English localization, clean automated accessibility/responsive/failure/privacy suites, valid content rights, approved performance budgets, and no unresolved P0/P1 issue. The platform being prepared has real-device, assistive-technology, moderated first-use, signing, artifact, migration, rollback, and store-draft evidence; any missing external input is visibly blocked. No ad SDK is present and no public release has occurred.
