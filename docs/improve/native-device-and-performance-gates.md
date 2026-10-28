# Native device, iOS, and performance gates

**Recorded:** 2026-10-28  
**Status:** Open; host tests and Android debug compilation do not close these
gates.

## Why these cannot be completed now

- No connected representative physical Android/iPhone/iPad matrix is available.
- The discovered physical iPhone was offline.
- Unsigned iOS preparation remained in CocoaPods while cloning the existing
  locked TensorFlowLiteSwift 2.12.0 source; it never reached Xcode compilation.
- The user stopped repeated native builds until Plans 01–08 are complete.
- Host/widget tests and mocked method channels cannot prove camera, Photos,
  MediaStore, receiving-app Share, memory, thermal, or real-device latency.

## Current safe evidence

- Room project/schema/recovery/export behavior has automated host coverage.
- Android debug compilation has passed previously; this is not release or
  physical-runtime evidence.
- Save/Share boundaries verify clean PNG bytes through mocked native channels.
- The iOS attempt is recorded as blocked/non-success, never as a compile pass.
- Manual Mask benchmark tooling labels simulator/host results as non-release
  evidence and does not claim an approved under-100-ms threshold.

## Required device evidence

- [ ] API 24 ARM32 low-memory Android phone.
- [ ] API 29 ARM64 Android phone.
- [ ] Current supported Android API phone.
- [ ] Android tablet and foldable/split-screen device.
- [ ] Minimum-supported iPhone.
- [ ] Current iPhone and iPad.
- [ ] Complete CocoaPods preparation, unsigned compile, then the separately
  authorized signing/archive gate for iOS.

## Runtime checks

- [ ] Real camera/gallery orientation and source-file preservation.
- [ ] Permission denial, Settings return, and retry on both platforms.
- [ ] Save to Photos/MediaStore; inspect filename, MIME, dimensions, pixels,
  metadata, and persistence after project deletion.
- [ ] Share/cancel through a real receiving app; inspect received bytes.
- [ ] Cached offline production-model inference after process restart.
- [ ] Background/foreground, low-memory, force-stop, and reopen recovery.
- [ ] Ten representative 1600-axis projects: storage, RSS, latency and cleanup.
- [ ] Manual brush feedback, command commit, autosave and reopen p50/p95 on
  named minimum and representative devices.
- [ ] Accessibility, RTL, 200% text, rotation, keyboard inset and fold/split
  verification on real target form factors.

## Acceptance and ownership

Device QA owns physical execution and raw evidence. iOS Release owns CocoaPods,
Xcode compile/archive and signing evidence. Mobile Performance QA owns named
device timing/memory measurements. Product approval is required before freezing
launch thresholds.

When Plans 01–08 are complete and the user authorizes native verification, run
each gate once, record exact device/build identifiers and outputs, and update
the release ledger. Do not repeat successful gates without a relevant code or
environment change.
