# Plan 04 — Smart Mask incomplete work

**Recorded:** 2026-10-28  
**Status:** Safe disabled/manual-only closure; conditional smart assistance is
not implemented or approved. Production remains `disabledByEvidence`.

This note tracks the Plan 04 work that must not be forgotten. Missing external
evidence does not block the Manual Mask experience or the rest of TintAtlas.

## Recorded closure and repository preparation

The [release decision](../release/smart-mask-decision.md),
[unsigned checklist](../release/smart-mask-evidence-checklist.md), and
[verification ledger](../release/verification-ledger.md) record the exact gate.

- Task 1 verifier/hash/human-audit preparation and Task 2 literal quality,
  correction-study validation, and decision tooling are implemented, uncommitted
  work with focused results in their SDD reports. They do not supply a corpus,
  human audit, correction sessions, or measured smart benefit.
- Task 3 boundary/visibility work is recorded separately in its implementation
  report and review; an ephemeral disabled boundary is not an algorithm or
  evidence that conditional MASK requirements are accepted.
- Task 4 is closed as `DISABLED_PENDING_EVIDENCE`, with no real guarded verifier
  invocation or signed human checklist. No corpus is frozen.
- Task 5 is explicitly SKIPPED / BLOCKED by the failed prerequisite. The manual
  baseline recorder/export and external 48-session baseline are not created or
  conducted on this path.
- Task 6 takes the `disabled` manual-only closure. No algorithm amendment,
  candidate constants, feature enable switch, smart claim, or dependency is added.
- One bounded source/copy scan records no Smart app/asset/README labels at scan
  time and no actual repository store/screenshot/ad artifacts. It does not review
  external store state, later Task 3 changes, or future assets. Final artifact
  verification remains with Release QA; the closure claims no full-suite or
  native-device/build result.

Conditional MASK-02/03/04/07/09/10/12 and EXTMASK-01 remain unaccepted. The
proposal-boundary tests and metric formulas alone cannot complete them. The
existing Manual Mask behavior ships independently, subject to its separately
recorded [device/performance gates](native-device-and-performance-gates.md).

## External evidence still required

- [ ] Exactly 24 lawfully usable representative real-room photos.
- [ ] Six each living-room, bedroom, kitchen-dining, other-indoor; all protocol
  scene/protection/lighting tags, all four paintable layers, protected ground
  truth in every image, and visual review for crops/rescales/near duplicates.
- [ ] Retained source and opaque oriented working bytes, exact source/revision,
  creator/title, license/version/URL, real acquisition date, and full permission
  text authorizing redistribution of each retained actual photo.
- [ ] Two real independent blind human annotators, each providing full-resolution
  ownership/protection maps with original bytes, actual UTC receipts, stable
  role IDs, and submission checksums for every photo.
- [ ] A third actual human adjudicator, different from both annotators, reviewing
  every dispute exactly once after both submissions arrive; final maps and
  explanations must match and agreed pixels remain unchanged.
- [ ] Approved provenance, independence, blindness, licensing, acquisition
  trail, manifest hashes, annotation hashes, and detached human attestation.

The existing protocol-v1 SHA-256 is pinned and unchanged:
`9bb3b0f379054af42598deebb4cc8a90e1a3e3a3a5cb5821c9587fc1281c31fb`.
Knowing this checksum does not supply the missing external corpus.

**Owners and unblock action:** the product owner commissions/provides the lawful
corpus, people, consent and private evidence archive; the acquisition reviewer
checks the actual photos/licenses/process and signs with the owner. They supply
the absolute corpus root and approved hash-bound redacted audit JSON. The
verifier operator runs the documented guarded release command with
`--require-adjudicated --human-audit`, archives stdout/stderr/exit code and
report/audit checksums, and copies only manifest/protocol/file hashes and audit
metadata into the ledger. Both automated exit 0 / `status: PASS` and approved
human review are necessary for `FROZEN_FOR_AMENDMENT`. A syntactically valid but
false/non-independent corpus still fails. Any evidence-byte change invalidates
the freeze and human audit. Private identities/signatures remain owner-held.

If any item above is unavailable or fails audit, record
`DISABLED_PENDING_EVIDENCE`. Downloaded images, generated/AI/synthetic images or
labels, predictions, invented identities/signatures, developer self-scoring and
temporary test fixtures cannot replace owner-provided lawful provenance,
independent annotations/adjudication, or real human correction sessions.

## Conditional work after evidence passes

- [ ] Freeze the verified corpus before viewing or designing a candidate.
- [ ] Run the manual baseline study: 8 consented participants × 6 assigned
  rooms = 48 completed sessions, balanced as two sessions per photo.
- [ ] Record anonymized timing, final-mask hashes, device/build IDs, quality
  metrics, exclusions, and dropouts.
- [ ] Implement/test the Task 5 offline recorder only after the freeze; register
  and freeze the manual assignment schedule before sessions, preserve monotonic
  timing, keep exclusions/dropouts separate, and include no raw photo bytes in
  exported reports.
- [ ] Score the untouched current MOSAIC/Manual Mask baseline using the same
  frozen loader, protocol tolerance, working pixels, target colors and settings;
  call `validateRoomBaselineSuitability` and freeze exact quality/report hashes.
- [ ] Study operations retain real consent and signed session-operation evidence;
  each photo has two distinct participants with counterbalanced order, and each
  of eight participants completes six assigned rooms without seeing model metrics.
- [ ] If the correction study is unavailable, record
  `DISABLED_PENDING_CORRECTION_STUDY`.
- [ ] Only after both gates pass, write and approve a separate Smart Mask
  algorithm amendment using independent calibration evidence.

**Owners and acceptance:** Study Operations recruits/consents participants,
freezes assignment/order and operates the actual sessions. The benchmark owner
records the frozen schedule/corpus/protocol/final-mask/report checksums, exact
commands, device/build IDs, quality and timing distributions. Invalid, missing,
overlapping or incomplete records do not improve medians or count as completed
sessions. Task 2 validation is tooling support, not study evidence. Only if the
corpus freeze has passed but sessions remain unavailable should the disposition
advance to `DISABLED_PENDING_CORRECTION_STUDY`; never replace the current earlier
blocker with an implied freeze.

## Enablement rules

Smart assistance may be considered only when all safety/reversibility gates
pass, median correction time improves, mean IoU regression is no worse than
0.01 absolute, and protected-object leakage does not worsen. A proposal must
change zero durable pixels until Apply; Apply is one exact command and one
autosave; stale proposals cannot apply.

Until a separate approved amendment and assisted study pass, do not implement
or enable connectivity, edge/color, depth, cleanup, island, hole-fill,
seed-radius, abstention thresholds, Smart controls, or Smart marketing claims.

**Later amendment owner:** the product owner approves a separately reviewed plan
only after frozen corpus and baseline acceptance. The algorithm owner identifies
immutable training/calibration evidence separate from evaluation; fixed candidate
constants; supported devices/timeouts; MASK-02/03/04/07/10/11/12 tests; exact
production provider binding; rollback; and preregistered paired/counterbalanced
manual/assisted study. No tuning against frozen evaluation outputs is permitted.
Real safety/reversibility/device evidence and a valid assisted study passing
`SmartMaskDecision.evaluate` are still necessary before enabling production;
missing/null data is `insufficientEvidence`. Release QA must verify the exact
app, store draft, screenshots and ads contain no Smart controls/claims while
disabled, including artifacts that do not yet exist in this repository.

## Files likely affected when reopened

- Owner-held corpus, original annotations/adjudication, provenance/consent,
  attestation and study-operation archive (private, outside tracked release docs).
- `docs/release/smart-mask-decision.md`, `smart-mask-evidence-checklist.md`,
  `verification-ledger.md` and this backlog note for accepted hashes/status.
- `tool/room_recolor/manual_correction_recorder.dart` and
  `test/tool/room_recolor/manual_correction_recorder_test.dart` (Task 5 only after
  frozen evidence); existing loader/metrics/study/decision tooling for scoring.
- A separately dated `docs/superpowers/plans/*-tintatlas-smart-mask-algorithm-amendment.md`
  and only the algorithm/provider/UI/tests it explicitly approves after review.
- Release-owned app/store/screenshot/ad artifacts and named-device verification
  records for the exact eventual candidate.

## Valid closure

Plan 04 may close safely as manual-only with Smart Mask disabled. That outcome
is not a product failure: Manual Mask ships, and the external evidence work
remains recorded here for a future improvement cycle.
