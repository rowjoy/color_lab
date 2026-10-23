# Color Formula independent review record

Date:2026-10-21. Reviews used file-scoped diffs from the previous Mixer source ZIP. No Git repository was created. All reviewers were read-only; none repeated full test/build checks or spawned additional reviewers.

## Task1 — math/models

Reviewer formula_math_review: spec compliant, quality approved, no Critical/Important/Minor findings. Exact immutable APIs/palette, once-consumed snapshots/validation, positive5% pairs/triples plus endpoints, strict displayed-result CIE76 minimum and stable ties conform. Independent midpoint/triple/error fixtures and differently structured exhaustive oracle support the algorithm. Reviewed unchanged mixer/RGB contracts for conversion/endpoint/snapshot risks only.

## Task2 — worker/providers

Reviewer formula_async_review: spec compliant, quality approved, no findings. Confirmed top-level compute callback calls the full shared search, no synchronous production search/global cache, retained target#B2A4D4 and value-keyed autoDispose family. Real service and Riverpod tests cover exact target forwarding, disposal/retry/late value/error behavior. Synchronous-search mutation RED demonstrates the responsiveness regression test is meaningful. Native device execution and later UI/full-suite checks remain root responsibilities.

## Task3 — presentation/entry/routing

Reviewer formula_ui_review: scoped code conforms, quality approved. No Critical or Important findings. One Minor test gap: stale-target widget test begins while the initial search is still pending, so a successful-visible-recipe→pending transition and a successful-key refresh are not explicitly asserted. Production code explicitly suppresses obsolete results and uses skipLoadingOnRefresh:false; this is coverage expansion, not an observed production bug. Carried to final reviewer for triage.

Confirmed actual recipe/error data, mounted picker/cancel, exact selected common-detail target entry without formula stacking, result-sourceLab save/details/Room, independent HSL/Mixer state, startup guard, shared tokens/actions/responsive layout and reduced-motion expansion. Delivery evidence and exact native/device behavior remain outside the scoped UI diff.

Root subsequently fixed a test-only brace lint and shortened a large-text heading while retaining the approximate subtitle/caveat. Fresh full384 tests, clean analysis/format,42 previews and Android debug APK are recorded in the progress ledger. Final reviewer receives this updated cumulative diff.

## Final whole-module review

Reviewer formula_final_review: Changes requested for one Important camera lifecycle integration issue; no Critical findings. The unawaited `/formula` push caused `showColorDetails` to return before formula closed, breaking the existing camera caller's awaited pause/resume lifetime. Depending on timing it could restart sampling behind formula or stay frozen after returning. Requested typed awaited push and real-router/fake-camera round-trip regression. The prior successful-visible→pending/refresh test gap remains a nonblocking Minor and is included in the same consolidated fix wave.

Otherwise confirmed exhaustive grid/endpoints and displayed-result score, immutable models/existing LAB reuse, compute boundary and keyed result disposal, exact targets/Room/save/drafts/guards and independent numeric/oracle tests. Inspected light and narrow2x dark previews; no clipping observed. Confirmed supplied384-pass suite log, without rerunning test/build commands.

### Declined to judge and root disposition

- Physical Android/iOS camera, sharing/permission and native accessibility: retain as explicit device-execution boundaries. This module adds no native SDK/configuration; fake-camera integration will test the new route lifecycle without claiming hardware evidence.
- Device latency, battery and sustained rapid selection: real VM compute tests/local timing are not hardware performance guarantees; no such guarantees are made.
- Complete contrast/accessibility certification: shared theme/control tests and selected screenshots support the UI, not native certification. Device audits remain separate.
- Final APK/archive integrity: root rebuilds and validates after the fix, not by reusing the pre-fix build.
- Independent analyzer/renderer reruns: reviewer accepted supplied evidence while inspecting code/screenshots/full-suite log; root owns fresh final commands.

### Consolidated fix wave and scoped re-review

Completed by formula_final_fix. Requirements/original findings are in formula-final-fix-brief.md, exact evidence in formula-final-fix-report.md. Source/test fix diff was scoped against the exact reviewed copies in a dedicated temporary baseline.

Reviewer formula_final_review scoped re-review: both findings ADDRESSED; no new breakage or out-of-scope observation. Approved final delivery, no unresolved findings. Confirmed the typed awaited push preserves the camera caller's lifetime and same-route guard. Camera regression uses the real router/screen, exact sampled target, no hidden restart and new replacement-session sample after Back. New successful-output tests cover both target change and same-key refresh, hide swatch/recipe/save/details while pending, then recover distinct literal output colors. Inspected camera RED/GREEN plus82 scoped/387 full-pass evidence without repeating checks.

Root independently reran387 full tests, whole analysis/format, final42-preview renderer, and rebuilt the APK after the fix. Archive validation is recorded separately in the ledger. All device/native/performance/certification caveats above remain explicit boundaries, not unresolved implementation findings.
