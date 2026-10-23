### Task 2: Three-slide onboarding presentation — delegated

**Files:** Create `lib/features/onboarding/presentation/onboarding_screen.dart` and optional `onboarding_art.dart`; tests `test/features/onboarding/onboarding_screen_test.dart`.

**Interfaces:** `OnboardingScreen({super.key, required Future<void> Function() onFinish, bool isReplay = false})`. It owns PageController/page index/busy/error only; no providers/native plugins. Root's callback persists completion or closes replay. Buttons call callback once per attempt and await it; while pending disable page changes/finish/skip and back via PopScope as appropriate. Show safe inline error on failure and allow retry. Do not pop automatically (router/caller owns finish behavior).

- [ ] Write tests first for 3 slides, Next/Back/swipe, Skip from any page, final Get started, callback only once while busy, failure retry, disposal during await,360x800 at2x text, portrait/short landscape and reduced motion.
- [ ] Implement using bundled typography/tokens/shared buttons, scrollable page content, static procedural illustrations, semantic step labels and48dp controls. Copy intent: discover camera/photo shades; keep a personal offline library; privacy and explicit permission rationale. No raster/network assets or unimplemented Room claims. Replay may label exit `Done` on final page; first run `Get started`.
- [ ] Scoped tests/analysis and report `docs/superpowers/plans/onboarding-ui-report.md`. No subagents or edits to routing/settings/root tests.

