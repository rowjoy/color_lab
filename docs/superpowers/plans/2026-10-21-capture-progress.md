# SDD ledger — plan: docs/superpowers/plans/2026-10-21-capture-photo.md

Ruling: “next” authorizes the document's Camera/Gallery/photo palette/detail module, not onboarding or real room-photo editing.

Ruling: Use system photo selection without broad media permission — the official image_picker API grants selected-file access; include only actually needed platform declarations.

| Tasks | Shared interface | Preflight |
| --- | --- | --- |
| 1 / 3 | PreparedPhoto and PhotoProcessor | Exact byte/dimension/sample/provider contracts |
| 2 / 4 | CameraSession and failure categories | Exact factory/lifecycle/preview/sample contract |
| 3 / 4 | PhotoPickerService, PhotoPickerScreen | Root owns entry/routing/error UI; delegated photo screen owns gesture state |
| 1 | Pure worker processing | No Flutter dependency in codec/math callback |
| 2 | Stream conversion | Stride/format/rotation fixtures and one in-flight worker |
| 3 | Gestures | Padded areas excluded; no one-finger pan fighting sampling |
| 4 | Existing behavior | Manual entry and history remain; native APIs injected in tests |

## Implementation and review

- Task 1 complete: immutable prepared snapshots, bounded first-frame decode, all EXIF orientations, white alpha compositing, matching preview/sample pixels, deterministic population palettes and isolate adapter. Scoped 35 tests and analysis passed; see `photo-processing-report.md`.
- Task 2 implemented: native permission/session adapter, stride-aware frame conversion, cover/rotation/mirror mapping, throttle/smoothing, serialized lifecycle and stale-result suppression. See `camera-backend-report.md`.
- Task 3 complete: system photo acquisition, Android lost-data recovery, photo sampling/loupe/pinch/pan, weighted population bars, gallery details/save and enlarged-text layout. Scoped 12 tests and analysis passed; see `photo-picker-report.md`.
- Task 4 integrated: Capture entry/recovery, full-screen routes, shared details/harmony/share/Room actions, native setup and preview tool. Independent review identified and prompted fixes for inactive-tab late navigation, transitive Android capabilities, population bars, hidden share errors and mutable outgoing Hero captures.
- Final camera permission-dialog lifecycle fix complete: interrupted initialization preserves denial before/after resume without an automatic second request. Canceled grants allocate no background camera, and explicit Settings return can recover. Rounded camera GlassBar uses AppRadii.large. The final 33 scoped camera tests passed with clean analysis; sample conversion math was unchanged.

## Native build diagnosis

Initial permission_handler13.0.2 resolved permission_handler_android14.1.0, whose Kotlin DSL assumes AGP9 built-in Kotlin. Its `kotlin.compilerOptions` failed against the existing AGP8 project. Constraining permission_handler to the12 line resolves12.0.3/Android13.0.1 and retains supported AGP8.12.1, Gradle8.14, Kotlin2.2.20 and Java17. Android compilation then passed. No cached third-party files were patched.

Fresh manifest inspection also found a merger-implied READ_EXTERNAL_STORAGE from CameraX's legacy WRITE declaration; the app explicitly removes both plus RECORD_AUDIO. Hardware camera/any/autofocus remain optional. Final merged-manifest check is required after rebuild.

## Verification boundaries

- Real-font previews include actual decoded photo fixtures and explicitly synthetic camera layouts, in light/dark themes. Visual inspection caught a tall pill-shaped GlassBar clipping camera controls; an optional shared corner-radius parameter allows a rounded camera card without changing navigation chrome.
- Emulator installation attempted with `adb -s emulator-5554 install -r ...` but returned `INSTALL_FAILED_INSUFFICIENT_STORAGE`. Existing device/app files were not cleared. A connected physical phone was not modified; native camera/picker execution remains unverified.
- `plutil -lint ios/Runner/Info.plist` and `ruby -c ios/Podfile` pass. iOS compilation and device execution are not claimed.

## Final verification — 2026-10-21

- `flutter test --reporter expanded`: **186 tests passed**, zero failures, exit0.
- `flutter analyze`: **No issues found**, exit0.
- `dart format --output=none --set-exit-if-changed lib test tool`: 70 files, zero changes, exit0.
- `flutter build apk --debug`: built `build/app/outputs/flutter-apk/app-debug.apk`, exit0.
- `flutter test tool/render_previews.dart --reporter expanded`: both theme render cases passed, generating14 PNGs. Photo images explicitly precache decoded pixels before capture; camera previews are labeled synthetic. Photo/palette and corrected dark camera-card previews visually inspected.
- Fresh merged manifest and `aapt dump permissions` on the final APK: CAMERA present; RECORD_AUDIO, READ_EXTERNAL_STORAGE and WRITE_EXTERNAL_STORAGE absent. Camera, camera.any and autofocus have required=false. Debug networking permissions are Flutter/plugin development capabilities, not an app server requirement.
- Source handoff: `dist/color-lab-capture-2026-10-21.zip`; archive integrity checked after creation. Previous Foundation and History archives preserved.

All four planned implementation tasks complete. Next module is onboarding and persisted settings; real room-photo editing remains Phase3.
