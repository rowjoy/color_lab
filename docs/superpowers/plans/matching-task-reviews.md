# Matching game scoped reviews

Date: 2026-10-21. Reviewers inspect exact task brief, implementer report and
full source/test diff against the previous Harmonies snapshot. Reviews are
read-only, with no nested agents or redundant full-suite/build runs.

## Task1 — scoring, targets, game and controller

Spec compliant; task quality approved. No findings.

Verified validated score rounding, bounded five-target generation, frozen RGB
attempts, RGB-only exactness, immutable target capture, retained raw HSL,
editing/feedback/complete guards, five-round result and atomic retained provider
restart. Tests use independent literal CIE76/near-match fixtures and actual
state/ProviderContainers, including neutral coordinates and failed replacement.

Named external dependency risk: existing RGB mutation/equality and neutral HSL
normalization. Focused inspection of `color_models.dart` confirms immutable
RGB/value equality and canonical neutral hue; the game retains its raw editing
coordinates separately, correctly avoiding an unintended reset.

Report evidence:28 focused tests, scoped clean analysis and seven formatted
files. The12 known sibling UI failures in the earlier aggregate run require
fresh root verification. UI/platform compatibility was not inferred from this
pure/controller task. Full report: `matching-task-1-report.md`.

## Task2 — screen and routing

Spec compliant; task quality approved. No findings. Actual Lab CTA/guarded
route, hidden target values/detail actions, RGB-only exactness, live feedback,
outside-scroll comparison and frozen-pair results match the brief. Confirmed
restart cancellation/disposal guards and delegation to the retained controller.

Tests cover literal numeric fixtures, frozen/stale callbacks, rounded100 wording,
retention, real failed history state and360px2×light/dark/reduced-motion layouts.
The compact pinned comparison has an observed scroll-to-Lightness RED before
implementation; no other product contracts/interfaces changed in that clarification.

Named external risks checked: shared tile semantics expose only supplied labels,
summary chips enforce48dp minimums, slider semantics and motion tokens propagate
correctly. No tests/builds were rerun by the reviewer. Native execution and core
scoring/generation are outside this UI diff, not unverified claims: core has its
own approved review; devices remain an explicit limitation. Full report:
`matching-task-2-report.md`.

## One final viewport fix wave

Root's final real-button probe found retained scroll offsets hiding summary and
replay entry. A scoped fix and two additional tests followed an observed RED.
The final reviewer approved the fix: resets are limited to new round/completion/
replacement-target transitions; ordinary slider/theme/submission offsets remain
intact. No new breakage or out-of-scope observations. Root's post-fix525-test
suite, clean analysis/format,82 previews and rebuilt APK supersede pre-fix counts.
