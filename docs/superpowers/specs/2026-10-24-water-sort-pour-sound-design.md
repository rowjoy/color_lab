# Water Sort Pour Sound Design

## Intent

Use the supplied `pour_bottle_clean.mp3` whenever a valid Water Sort move reaches the visible water-pouring phase. Keep the game offline, keep the sound toggle behavior, and leave every other game sound unchanged.

## Constraints

- Bundle one copy at `assets/audio/pour_bottle_clean.mp3`.
- Preserve the existing `GameAudio.playWaterPour(amount)` MethodChannel contract and the once-per-pour trigger in `WaterSortScreen`.
- Play only the portion matching the existing amount-dependent pour duration (`450 + 260 * amount` milliseconds, with amount clamped to 1–4), so audio does not linger into the next move.
- Preserve all unrelated dirty-worktree changes; do not commit them.

## Approaches

1. **Existing native channel + bundled Flutter asset (selected):** Android loads the asset with `MediaPlayer`; iOS loads it with `AVAudioPlayer`. This keeps the existing audio architecture and adds no dependency.
2. **Flutter audio plugin:** simpler Dart-only playback, but adds a package and platform plugin dependencies for one sound.
3. **Duplicate native resources:** copy the MP3 into Android and iOS projects separately. This avoids Flutter asset lookup but creates two copies that can drift.

## Verification

Add an asset-bundle test, retain the MethodChannel payload/clamping tests, run the focused game-audio and pour-motion tests, analyze the changed Dart code, and compile the Android/iOS platform integrations when the local toolchain permits.
