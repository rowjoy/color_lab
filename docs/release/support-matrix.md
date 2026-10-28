# TintAtlas launch support matrix

**Recorded:** 2026-10-27

**Status:** provisional platform contract; public-release device gates remain blocked pending named physical hardware

## Toolchain baseline

| Component | Recorded baseline | Policy |
| --- | --- | --- |
| Flutter | 3.41.1 stable, framework `582a0e7c55` | Pin while Android API 24/iOS 13 feasibility is being proved; an upgrade requires a fresh floor/plugin/model review. |
| Dart | 3.11.0 | Follows the pinned Flutter SDK. |
| Android compile/target SDK | 36/36 from the installed Flutter toolchain | Meets the recorded 2026 Play target level; re-check the [official target-SDK requirement](https://developer.android.com/google/play/requirements/target-sdk) for every release. |
| Android NDK | `28.2.13676358` from Flutter | Re-run native/TFLite ABI tests after a change. |
| Xcode/macOS host | Xcode 26.2 (`17C52`) on macOS 26.6.2, Apple Silicon | Host fact only; it is not iPhone/iPad compatibility evidence. |

## Launch form factors

- In scope: Android and iOS phones/tablets, portrait and landscape.
- Adaptive-window scope: Android resizable/multi-window and foldable widths; iPad split-view/Stage Manager widths.
- Out of scope for public v1: web and desktop distribution.
- Simulators/emulators may prove layout and navigation, but camera behavior, memory, heat, battery, and ML latency require physical devices.

## Android contract

| Dimension | Repository/current build | Launch decision |
| --- | --- | --- |
| Minimum OS | API 24 in `android/app/build.gradle.kts` | Retain provisionally; physical API-24 ARM32 evidence is required before release sign-off. |
| Target/compile | API 36 | Retain for current toolchain; re-evaluate at each store submission. |
| Release ABIs | `armeabi-v7a`, `arm64-v8a`, `x86_64` present in the measured universal release APK | ARM32/ARM64 are device commitments; x86_64 is emulator/install smoke, not ML-performance evidence. Flutter's architecture guidance is in the [Android deployment documentation](https://docs.flutter.dev/deployment/android). |
| Camera availability | Manifest declares camera features optional | Gallery/sample-room paths must remain usable without camera hardware. |
| Application ID/signing | `com.example.color_lab`; release build currently uses debug signing | Not publishable; identity gate and production signing remain blocked. |

The 2026-10-27 release-mode APK built successfully on this host. It is a universal, debug-key-signed engineering artifact, not a store candidate.

## iOS contract

| Dimension | Repository/current build | Launch decision |
| --- | --- | --- |
| Deployment target | iOS 13.0 in Podfile and all Runner build configurations | Provisional only with Flutter 3.41.x/Xcode 26 pinned. No public iOS claim until archive and real-device evidence pass. |
| Devices | `TARGETED_DEVICE_FAMILY = "1,2"` | iPhone and iPad are intended. |
| Release device architecture | No project override; ARM64 device build expected | Verify archive slices before sign-off. Simulator slices do not satisfy the device gate. |
| Bundle ID/signing | `com.example.colorLab`; no approved production identity | Not publishable; see `identity-decision.md`. |

Flutter's current [supported-platforms reference](https://docs.flutter.dev/reference/supported-platforms) has moved to newer iOS floors. Before adopting Flutter 3.47+/Xcode 27, raise the proposed floor to iOS 15 and obtain product-owner approval after dependency, migration, and device review. Do not silently drop iOS 13 while the current contract is provisional.

## Required physical-device evidence

| Evidence ID | Minimum hardware class | Required checks | State / owner |
| --- | --- | --- | --- |
| AND-LOW-24 | API 24, ARM32, 2–3 GB RAM Android phone | Install, cold start, gallery/save, memory pressure, Room model download/inference, restart recovery | blocked — Device Lab owner must record model, OS/build, RAM, storage, and results |
| AND-MID-29 | API 29, ARM64 Android phone | Scoped-storage boundary, camera/gallery/export, offline restart | blocked — Device Lab |
| AND-CUR-36 | API 36, ARM64 current mainstream phone | Target-SDK permissions, camera, ML/recolor latency, heat/battery smoke | blocked — Device Lab |
| AND-TAB | ARM64 Android tablet or foldable | Width classes, rotation, multi-window/hinge, external input | blocked — Device Lab |
| IOS-MIN-13 | ARM64 iPhone capable of iOS 13 | Minimum-floor install/start, permissions, camera/gallery/export, ML | blocked — iOS release owner; remove this row only through approved floor change |
| IOS-CUR | Current ARM64 iPhone/latest supported iOS | Camera, permissions, Room ML, performance, background/restart | blocked — iOS release owner |
| IPAD-CUR | ARM64 iPad | All orientations, split view, keyboard, editor reachability, ML | blocked — iOS release owner |

An API 36 x86_64 emulator and iPhone/iPad simulators are also required for deterministic UI/navigation checks. They supplement, never replace, the physical rows.

## Responsive test matrix

Automated/widget and manual checks must cover 320×568, 360×800, 390×844, 568×320, 844×390, 600×960, 800×1280, 1024×1366, and 1280×800 logical layouts; default/intermediate/200% text; light/dark; reduced motion; RTL/long strings; keyboard/safe-area variations; and live resize/orientation without state loss.

## Release rules

- Android public release is allowed only after shared gates plus all Android rows pass; unfinished iOS work does not block Android.
- iOS public release is allowed only after shared gates, archive verification, and every required iPhone/iPad row pass.
- A support-floor increase requires measured evidence, impact notes, and explicit product-owner approval.
- A plugin, model, or toolchain upgrade that changes OS/ABI support reopens this matrix.

## Plan 03 manual correction gate — open physical evidence

The Tasks 4–6 coding batch adds responsive review/precision controls and writes
focused checks for 320×568, 568×320, expanded widths, RTL, high contrast, 200%
text, source-coordinate/DPR consistency, gesture cancellation and resize.
These new tests have not been executed during coding; a parent-owned combined
focused run is planned with an overall 60-second bound. Layout/unit checks
cannot establish physical-device support or assistive-technology usability.

| Required evidence | Current status |
| --- | --- |
| Named minimum + representative Android devices: pointer-event→visible feedback p50/p95, command commit, autosave acknowledgment, peak history/memory, reopen recovery | OPEN; no device run or measured threshold approval |
| iPhone/iPad measurements and independent iOS gate | OPEN; no physical iOS result |
| Rotation/background kill, keyboard/pan/zoom, TalkBack/VoiceOver, high contrast and 200% text on physical hardware | OPEN; focused recovery/layout tests written only |
| Feedback acceptance threshold | OPEN; under 100 ms is a design target, not a frozen or achieved gate |
| Full tests, analyzer/formatter and native builds | Not run in this coding batch at user direction; broader/native checks remain deferred to approved Plan 08 completion |

The synthetic manual-mask benchmark labels default host/simulator output
`non-release`; UI feedback stays unmeasured unless an actual trace is supplied.
Synthetic command correctness does not establish mask accuracy or replace the
separate external smart-mask evidence gate. Existing platform floors, native
configuration, dependencies and permissions are unchanged.
