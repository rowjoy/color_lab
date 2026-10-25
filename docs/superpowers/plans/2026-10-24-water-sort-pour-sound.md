# Water Sort Pour Sound Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Play the supplied bottle-pour MP3 once during each valid Water Sort pour.

**Architecture:** Preserve `GameAudio.playWaterPour(amount)` and its MethodChannel. Bundle the MP3 as a Flutter asset, then replace only the native procedural `waterPour` synthesis with duration-capped asset playback on Android and iOS.

**Tech Stack:** Flutter asset bundle, Dart MethodChannel, Android MediaPlayer, iOS AVAudioPlayer

**Spec:** `docs/superpowers/specs/2026-10-24-water-sort-pour-sound-design.md`

## Global Constraints

- Keep the existing once-per-valid-pour UI trigger and sound toggle behavior.
- Clamp pour amount to 1–4 and cap playback to `450 + 260 * amount` milliseconds.
- Do not alter other synthesized game sounds.
- Preserve unrelated uncommitted work; do not create a commit unless the user requests one.

## Review Focus

- Missing asset: the asset-bundle test must fail rather than silently shipping no sound.
- Repeated animation frames: the existing `_pourSoundStarted` guard must still emit one call.
- Short pours: playback must stop at the amount-dependent duration.
- Consecutive pours: each native player must release or replace its previous instance safely.
- Muted game: the existing UI guard must continue to suppress the call.

---

### Task 1: Bundle and contract-test the MP3

**Files:**
- Create: `assets/audio/pour_bottle_clean.mp3`
- Modify: `pubspec.yaml`
- Test: `test/features/games/application/game_audio_test.dart`

**Interfaces:**
- Consumes: `/Users/jamirulislam/Downloads/pour_bottle_clean.mp3`
- Produces: Flutter asset key `assets/audio/pour_bottle_clean.mp3`

- [x] Add a failing test that loads the exact asset key and asserts it is non-empty.
- [x] Run the focused test and confirm it fails before the asset is declared.
- [x] Copy the supplied MP3 and declare it under Flutter assets.
- [x] Run the focused test and confirm the asset and existing MethodChannel tests pass.

### Task 2: Replace procedural pour synthesis with the bundled recording

**Files:**
- Modify: `android/app/src/main/kotlin/com/example/color_lab/MainActivity.kt`
- Modify: `ios/Runner/AppDelegate.swift`
- Modify: `lib/features/games/application/game_audio.dart`

**Interfaces:**
- Consumes: MethodChannel effect `waterPour`, clamped `amount`, and Flutter asset key from Task 1
- Produces: Android/iOS playback capped to `450 + 260 * amount` milliseconds

- [x] On Android, resolve the Flutter asset key, play it with `MediaPlayer`, stop at the cap, and always release resources.
- [x] On iOS, resolve the same key, retain an `AVAudioPlayer`, cancel stale stop work, and stop at the cap.
- [x] Update the Dart service comment to distinguish recorded pour audio from synthesized effects.
- [x] Run focused tests, Dart analysis, and platform compilation checks.
