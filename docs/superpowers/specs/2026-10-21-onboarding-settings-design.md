# Onboarding and persistent settings

The user's “Next” continues step5 of the supplied Color Lab build specification after Camera/Gallery delivery. Implement this module only; do not start Phase2 or room-photo editing. The document already supplies purpose, constraints and the module-by-module execution instruction, so no additional approval question is required.

## Outcome

- First launch presents three short, skippable English slides with procedural/code-native illustrations, existing light/dark tokens, accessible controls and reduced-motion behavior.
- Slides explain discovering colors through camera/photo, saving an offline color library, and on-device privacy/permission rationale. They do not claim unimplemented room-photo features. No camera/gallery permission is requested during onboarding.
- Skip and Get started both durably mark onboarding complete before entering Capture. Failure stays on the tour with a friendly retryable message. Returning users bypass the tour.
- System/Light/Dark choices persist across a real close/reopen. System remains the default and follows OS brightness. Stored appearance is loaded before entering the main screens.
- Existing Appearance settings remains reachable from each studio tab, gains durable-save feedback, privacy copy and replay-tour access, and retains About/licenses. Replaying the tour does not reset completion, theme or saved colors.

## Architecture

Reuse Hive2 and path_provider; no new dependencies or platform permission changes. A dedicated app-private `app_preferences_v1` box stores one validated version1 preferences map, separate from color history. Use a repository interface and an AsyncNotifier to serialize read-modify-write operations, prevent theme/onboarding updates from clobbering each other, and publish only after flush. Failed flushes must block read/no-op success until retried. Do not clear corrupted/unsupported storage automatically.

An overridable preferences repository provider owns initialization/close. A lightweight startup route waits for preferences and offers explicit retry on load failure without raw exceptions. A stable GoRouter listens to preference state instead of being recreated when appearance changes. Guard all content routes until onboarding is complete. A separate replay route returns to the previous screen.

Keep the existing `themeModeProvider`/`setMode` call sites compatible; derive the visible mode from loaded preferences and make `setMode` return the persistence Future. In the Appearance sheet, disable competing selection while saving, retain the last committed mode on failure, and show an inline error. Main-screen navigation state survives theme changes.

## Persistence policy

`AppPreferences(themeMode: ThemeMode.system, onboardingCompleted: false)` is the empty-store default. Persist `schemaVersion:1`, `themeMode:'system'|'light'|'dark'`, and `onboardingCompleted:bool`. Unknown/invalid theme values fall back to System; a malformed completion flag falls back to false without losing a valid theme. Unsupported schema versions and non-map records report a safe storage error and are preserved. Reads, writes and close serialize; repositories use an isolated Hive registry so tests/paths cannot share boxes accidentally.

## Verification

Test model validation, actual file reopen and independent directories, queueing, failed writes/flushes/close, late disposal/factory retry, and concurrent theme/onboarding edits. Widget coverage includes first-launch slides/skip/completion/relaunch, saved-dark startup, load/write retry, no automatic permission calls, 360px/2x text, reduced motion, replay return, retained Lab state and existing Capture/history flows. Render both themes, run the full suite/analyzer/formatter and debug Android build, then package a cumulative source ZIP. Report native device verification boundaries honestly; do not delete emulator or user data to make tests run.
