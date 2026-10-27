# TintAtlas Conditional Smart Masks Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prepare a safe, disabled-by-default smart-mask proposal boundary and make an auditable evidence decision without inventing human ground truth or shipping an unvalidated algorithm.

**Architecture:** Keep smart output outside the durable mask until the user previews and applies one exact command keyed to project/photo/layer/revision. Validate and freeze the existing independent 24-photo protocol before any connectivity, edge, depth, cleanup threshold, or candidate implementation; this plan ends in either a documented disabled release or a separately approved post-freeze algorithm amendment.

**Tech Stack:** Dart benchmark tooling, existing Room quality metrics, Flutter/Riverpod proposal contracts, Manual Mask command/history, JSON evidence reports, unit/widget/tool tests.

**Spec:** `docs/superpowers/specs/2026-10-27-tintatlas-full-product-design.md`

## Global Constraints

- Read the master, Real-Room, Manual Mask, and `docs/superpowers/plans/room-recolor-annotation-protocol.md` plans first.
- EXTMASK-01 requires exactly 24 lawfully usable representative real photos, two independent human annotators, and a third human adjudicator; code, synthetic/AI images, model masks, developer self-scoring, or invented identities cannot substitute.
- Protocol v1 SHA-256 remains `9bb3b0f379054af42598deebb4cc8a90e1a3e3a3a5cb5821c9587fc1281c31fb`; do not edit/relabel it after candidate viewing.
- Do not define, tune, or implement connectivity, color/edge, depth, island, hole-fill, seed-radius, or abstention thresholds before the adjudicated corpus freeze passes and its hashes are recorded.
- Production availability defaults to `disabledByEvidence`; when disabled, no smart control or smart-correction marketing claim is rendered.
- A proposal changes zero durable pixels until Apply; Cancel changes zero pixels; Apply is one existing `MaskEditCommand` and one autosave; a stale key cannot apply.
- Smart assistance may launch only if all reversibility/safety gates pass, median correction time improves, mean IoU regresses by no more than 0.01 absolute, and protected-object leakage does not worsen. A 25% time reduction and 10% relative leakage reduction are stretch goals only.

## Review Focus

- A syntactically valid manifest with false/non-independent provenance is rejected by the human audit even if automated checks pass.
- A proposal completing after photo/project/layer/mask revision changes is discarded and cannot flash into preview or history.
- Empty seed regions, image-edge seeds, missing depth, timeouts, memory pressure, and ambiguous/large regions abstain safely without altering masks.
- Disabling evidence availability removes controls and claims while leaving all Manual Mask actions fully usable offline.
- Metric denominators, null jointly absent layers, participant dropouts, incomplete sessions, and paired/counterbalanced timing records cannot silently improve the decision.

---

### Task 1: Lock the external evidence protocol and decision record

**Files:**
- Create: `docs/release/smart-mask-decision.md`
- Create: `docs/release/smart-mask-evidence-checklist.md`
- Modify: `docs/release/verification-ledger.md`
- Modify: `tool/verify_room_recolor_benchmark.dart`
- Modify: `test/tool/room_recolor/benchmark_test.dart`
- Test: `test/tool/verify_room_recolor_benchmark_test.dart`

**Interfaces:**
- Consumes: existing `loadRoomRecolorBenchmark(..., requireAdjudicatedAnnotations: true)` and immutable protocol v1.
- Produces machine-readable verifier fields for all source/working/annotation file hashes plus `humanAuditStatus`; the human checklist records lawful redistribution, near-duplicate review, verified identities, independence, blindness, adjudicator difference, and acquisition trail. Raw legal names/contact details stay in owner-held evidence; tracked files retain role IDs, decision, date, and the external attestation checksum only.

- [ ] **Step 1: Write RED verifier tests.** Require exact 24/category/tag coverage, all file hashes, adjudicated maps, two distinct annotator identities, a third identity, chronological submissions, complete dispute coverage, and explicit failure when `humanAuditStatus` is absent/not approved in release mode.
- [ ] **Step 2: Run `flutter test --no-pub test/tool/room_recolor/benchmark_test.dart test/tool/verify_room_recolor_benchmark_test.dart --reporter expanded`.** Expected: FAIL on the new report/audit contract.
- [ ] **Step 3: Extend reports without changing protocol bytes or accepting weaker evidence.** Automated validation must state what it cannot prove; the human reviewer signs the detached checklist after visually checking photos/licenses/people/process.
- [ ] **Step 4: Run the tool tests and `dart run tool/verify_room_recolor_benchmark.dart --help`.** Expected: PASS/usage exit 64 as currently documented, without creating or repairing a corpus.
- [ ] **Step 5: Commit.** `git commit -m "test: lock the smart mask evidence gate"`.

### Task 2: Complete literal quality and correction-effort metrics

**Files:**
- Modify: `tool/room_recolor/quality_metrics.dart`
- Create: `tool/room_recolor/correction_study.dart`
- Create: `tool/room_recolor/smart_mask_decision.dart`
- Modify: `tool/verify_room_recolor_benchmark.dart`
- Modify: `test/tool/room_recolor/quality_metrics_test.dart`
- Create: `test/tool/room_recolor/correction_study_test.dart`
- Create: `test/tool/room_recolor/smart_mask_decision_test.dart`

**Interfaces:**
- Extends per-layer metrics with pixel `precision`, `recall`, and `dice`; adds genuine-wall-retention numerator/denominator beside IoU, boundary F1, and protected leakage.
- Produces strict `CorrectionStudyRecord` entries keyed by corpus photo, anonymized participant, method (`manual` or `assisted`), assignment/order, monotonic duration milliseconds, completion status, final mask hash, and final quality metrics. `validateManualBaseline()` accepts only the separately frozen manual schedule; `validateComparison()` requires the later amendment's pre-registered manual/assisted balance and cannot reuse the baseline-only result as an assisted comparison.
- Produces `SmartMaskDecision.evaluate(baseline, candidate, study)` returning only `pass`, `fail`, or `insufficientEvidence`, with each mandatory rule and stretch result reported separately.

- [ ] **Step 1: Write RED literal-metric tests using hand-countable masks.** Pin TP/FP/FN, precision/recall/Dice, IoU, boundary F1, protected leakage, genuine-wall retention, null jointly absent classes, and unweighted corpus aggregation.
- [ ] **Step 2: Write RED correction-study tests.** Reject duplicate assignments, nonpositive durations, incomplete sessions counted as completions, mismatched final hashes, and median calculations that include invalid records; baseline mode rejects assisted rows, while comparison mode rejects missing manual/assisted photo coverage or a schedule that differs from the later pre-registration.
- [ ] **Step 3: Write RED decision-rule tests.** Pass requires safety/reversibility true, improved median time, IoU delta `>= -0.01`, leakage delta `<= 0`; exactly 25%/10% is reported as stretch achieved but does not replace mandatory rules; null/insufficient data never passes.
- [ ] **Step 4: Run `flutter test --no-pub test/tool/room_recolor/quality_metrics_test.dart test/tool/room_recolor/correction_study_test.dart test/tool/room_recolor/smart_mask_decision_test.dart --reporter expanded`.** Expected: FAIL.
- [ ] **Step 5: Implement the literal formulas/report types and JSON output.** Keep boundary tolerance pinned by protocol v1 and do not add candidate thresholds.
- [ ] **Step 6: Run the focused tooling suites twice and inspect deterministic JSON ordering.** Expected: PASS.
- [ ] **Step 7: Commit.** `git commit -m "test: measure smart mask quality and effort honestly"`.

### Task 3: Disabled-by-default proposal boundary and exact command semantics

**Files:**
- Create: `lib/features/room_studio/domain/smart_mask_proposal.dart`
- Create: `lib/features/room_studio/refine/smart_mask_proposal_service.dart`
- Create: `lib/features/room_studio/application/smart_mask_proposal_controller.dart`
- Create: `lib/features/room_studio/presentation/smart_mask_proposal_controls.dart`
- Test: `test/features/room_studio/domain/smart_mask_proposal_test.dart`
- Test: `test/features/room_studio/application/smart_mask_proposal_controller_test.dart`
- Test: `test/features/room_studio/presentation/smart_mask_proposal_controls_test.dart`

**Interfaces:**
- Produces `SmartMaskAvailability.disabledByEvidence` as the only production value in this plan; `SmartMaskAction { add, remove, cleanup }`; `SmartMaskProposalKey(projectId, photoId, maskRevision, layer, action)`; and `SmartMaskProposal(key, command, previewMasks)`.
- Produces:
  ```dart
  abstract interface class SmartMaskProposalService {
    Future<SmartMaskProposal?> propose({
      required SmartMaskProposalKey key,
      required Offset normalizedSeed,
      required PreparedPhoto photo,
      required MaskBitmap aiMasks,
      required MaskBitmap currentMasks,
      required MaskIntentBitmap intent,
      required RoomDepthFrame? depth,
    });
  }
  ```
- `DisabledSmartMaskProposalService.propose()` returns `null` without inspecting user pixels; controller methods are `requestProposal(...)`, `applyProposal(SmartMaskProposalKey)`, and `cancelProposal()`.

- [ ] **Step 1: Write RED invariant/controller tests with a fake service.** Validate finite normalized seeds, aligned preview/command dimensions, matching project/photo/layer/revision/action, one in-flight request, Cancel zero pixels, Apply one command/save, double Apply rejection, and all stale-key permutations.
- [ ] **Step 2: Write RED production-visibility tests.** With `disabledByEvidence`, the editor contains no Smart Add/Remove/Cleanup semantics, service receives no photo/depth/mask data, Manual Add/Erase/Undo/Redo remain present, and About/marketing copy makes no smart claim.
- [ ] **Step 3: Run the focused proposal suites.** Expected: FAIL because the boundary does not exist.
- [ ] **Step 4: Implement types/controller/fake-test seam and disabled production provider only.** The preview is ephemeral; Apply delegates the existing Manual Mask one-command path; no proposal algorithm or production enable switch is implemented.
- [ ] **Step 5: Run proposal plus all Manual Mask controller/integration tests.** Expected: PASS with byte-identical durable masks while disabled/cancelled.
- [ ] **Step 6: Commit.** `git commit -m "feat: add a disabled safe smart mask boundary"`.

### Task 4: Freeze-or-disable external gate

**Files:**
- Modify: `docs/release/smart-mask-evidence-checklist.md`
- Modify: `docs/release/smart-mask-decision.md`
- Modify: `docs/release/verification-ledger.md`
- Modify: none of the proposal algorithm files

**Interfaces:**
- Consumes the product-owner-supplied external corpus root and human audit; produces one immutable outcome: `FROZEN_FOR_AMENDMENT` with recorded hashes, or `DISABLED_PENDING_EVIDENCE`.

- [ ] **Step 1: Before viewing or implementing any candidate, run the guarded verifier exactly as documented:** `dart run tool/verify_room_recolor_benchmark.dart --root <absolute owner-supplied corpus root recorded in the ledger> --require-adjudicated`. Expected for an enabled path: exit 0, `status: PASS`, exactly 24 distinct photos, adjudicated annotations true, pinned protocol hash, and complete manifest/file hashes.
- [ ] **Step 2: Complete the human provenance/independence checklist.** The acquisition reviewer and product owner sign the owner-held attestation; the tracked checklist records redacted role IDs/date/checksum. Automated PASS alone cannot approve the evidence.
- [ ] **Step 3: If either step fails or the corpus is unavailable, record `DISABLED_PENDING_EVIDENCE`, retain `disabledByEvidence`, skip Tasks 5–6, and ship the proven manual flow.** Do not manufacture substitute files or mark MASK-02/03/07/09/10/12 complete.
- [ ] **Step 4: If both pass, copy only hashes/audit metadata—not licensed photo bytes—into the ledger, mark the evaluation set frozen, and continue.** Any protocol/corpus byte change invalidates the gate and returns availability to disabled.
- [ ] **Step 5: Commit the evidence-status documents only.** `git commit -m "docs: record the smart mask evidence gate"`.

### Task 5: Measure the frozen manual baseline before candidate design

**Files:**
- Create: `tool/room_recolor/manual_correction_recorder.dart`
- Create: `test/tool/room_recolor/manual_correction_recorder_test.dart`
- Modify: `docs/release/smart-mask-decision.md`
- Modify: `docs/release/verification-ledger.md`

**Interfaces:**
- Runs only after `FROZEN_FOR_AMENDMENT`; records the frozen current MOSAIC/Manual Mask quality and correction sessions without proposing an algorithm.
- Manual timing protocol uses 8 consented participants × 6 assigned rooms = 48 completed sessions, balanced across the 24 photos so each photo has two independent manual sessions; order is counterbalanced and the participant does not see model metrics.

- [ ] **Step 1: Write RED recorder tests.** Require frozen manifest/protocol hashes, anonymous participant IDs, exactly 48 complete sessions with 8×6 and 2-per-photo balance, monotonic timing, final mask hashes, device/build IDs, no raw photo bytes in the report, and separate excluded/dropout records.
- [ ] **Step 2: Run recorder/tool tests.** Expected: FAIL before the recorder exists.
- [ ] **Step 3: Implement the offline recorder/export and score the untouched current baseline through the same corpus loader/metrics.** Call `validateRoomBaselineSuitability`; do not tune or view a candidate.
- [ ] **Step 4: Conduct the external manual sessions and record signed study-operation evidence.** If people/sessions are unavailable, record `DISABLED_PENDING_CORRECTION_STUDY` and keep production disabled.
- [ ] **Step 5: Freeze baseline quality, timing distribution, device/build, commands, and hashes in the decision document; run all tool tests.** Expected: deterministic report and no candidate constants/code.
- [ ] **Step 6: Commit.** `git commit -m "test: freeze the manual mask baseline"`.

### Task 6: Create the post-freeze algorithm amendment or close disabled

**Files:**
- Create only on a passed Tasks 4–5 path: `docs/superpowers/plans/YYYY-MM-DD-tintatlas-smart-mask-algorithm-amendment.md`
- Modify: `docs/release/smart-mask-decision.md`
- Modify: `docs/release/verification-ledger.md`

**Interfaces:**
- The amendment must name exact immutable training/calibration evidence separate from the frozen evaluation set, fixed candidate connectivity/edge/depth/cleanup/abstention constants, supported devices/timeouts, study design, production provider binding, rollback, and every MASK-02/03/04/07/10/11/12 test.
- No algorithm file/provider/UI availability change is authorized by this current plan.

- [ ] **Step 1: If Tasks 4–5 did not pass, finalize `disabled` with the manual-only release behavior and verify no smart controls/claims in app, store draft, screenshots, or ads.**
- [ ] **Step 2: If Tasks 4–5 passed, write the separate exact amendment without reading/tuning against frozen evaluation outputs beyond the recorded baseline.** Use independent calibration evidence and require product-owner approval before code.
- [ ] **Step 3: Run format, analyze, full tests, proposal/manual suites, and repository copy scan for smart claims.** Expected: clean and production remains disabled under this plan.
- [ ] **Step 4: Record the outcome and obtain fresh safety/evidence review.** Do not check Conditional MASK implementation IDs as complete unless an approved amendment is later executed and its assisted study passes `SmartMaskDecision.evaluate`.
- [ ] **Step 5: Commit.** `git commit -m "docs: close the conditional smart mask decision"`.

## Exit Gate

This plan has two valid outcomes. Without complete external evidence/baseline, smart controls and claims remain absent while Manual Masks ship. With valid frozen evidence, a separately reviewed algorithm amendment—not this plan—may define and implement the candidate, after which a counterbalanced assisted study and MASK-12 decision must still pass before enabling production. At no point does missing evidence block the rest of TintAtlas v1.
