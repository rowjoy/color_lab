# Plan 05 — Illustrated Rooms v2 incomplete work

**Recorded:** 2026-10-28  
**Status:** Tasks 1–8 are implemented and review-approved. Tasks 6–8 focused
verification is closed with split failure-specific evidence; deferred release
gates below remain.

## Deferred integration

- Register `assets/licenses/illustrated-room-palettes-NOTICE.txt` in the runtime
  `LicenseRegistry` list in `lib/main.dart` when that protected file is authorized
  for a focused edit. The notice is already bundled by `pubspec.yaml`, but it is
  not yet visible in the About/license screen.
- Run the Plan 05 full-suite and Android/iOS build gates only after the user's
  Plans 01–08 are complete. Until then, use task-focused RED/GREEN tests and
  scoped analysis; do not claim release readiness.
- Re-triage the three disclosed real-photo integration expectations before the
  final full gate: fullscreen canvas height (actual 271 vs expected >300) and
  gallery/camera import copy expecting three `Not detected` labels.
- Measure the six-template bounded app-lifetime decoration cache on named
  devices during the deferred performance gate. The final inventories can
  retain 232 small `Picture` objects (colored and grayscale decoration slots);
  focused software tests do not establish memory/frame-time readiness.
- Exercise actual illustrated-room Gallery and Share on supported Android and
  iOS devices, including permission denial/retry, backgrounding before native
  handoff, iPad origin, dismissal/unavailable results, safe filenames, clean
  PNG metadata and external-copy survival. Mocked boundaries are not a native
  runtime pass.
- Obtain owner/legal confirmation for the repository-authored room artwork or
  add an explicit room-artwork license/notice before public distribution. Git
  authorship records provenance but is not an independently verified rights
  grant; the palette NOTICE does not cover SVG/JSON artwork.
- Hive evidence covers flush/close/reopen and rollback, not device power loss
  during a failed mutation. A terminal Hive close error requires a fresh owner;
  the closed repository handle cannot be retried.
- Add exact edit/Undo/Redo/persisted-snapshot assertions to every constrained
  responsive matrix case. Task 5 has exact mutation evidence in its keyboard and
  focused flow tests, but the per-size matrix currently proves reachability and
  layout more strongly than state transitions.
- Add a fixture that forces the draft-store identity epoch to change while an
  older retain is actively awaiting persistence. Current round-2 tests cover
  atomic Update, rollback, fresh reopen, queued operations, and stale-draft
  replay, but not that exact internal timing branch.

## Remaining Plan 05 gates

- Retain the exact Task 6/7 split verification and Task 8 6/6 milestone evidence
  recorded in `docs/release/verification-ledger.md`; do not reinterpret it as a
  full-suite or native pass.
- Run the deferred Plan 05 full suite, analyzer, Android/iOS build and device
  gates only at the user's approved Plans 01–08 release checkpoint.
