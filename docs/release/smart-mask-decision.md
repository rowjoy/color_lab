# Conditional smart-mask evidence decision

Recorded: 2026-10-28. Plan 04 Tasks 4–6 take the disabled/manual-only closure.

Current disposition: **DISABLED_PENDING_EVIDENCE**. Production availability stays
`disabledByEvidence`; smart controls and claims remain absent. Manual Mask and
later non-smart plans may proceed. This record does not enable smart assistance
or mark Conditional MASK-02/03/04/07/09/10/12 or EXTMASK-01 complete.

No owner-supplied audited 24-photo corpus, verified human submissions,
adjudication, or signed external attestation is available. The current evidence
record is:

| Evidence | Value |
| --- | --- |
| Protocol version | v1, unchanged |
| Protocol SHA-256 | `9bb3b0f379054af42598deebb4cc8a90e1a3e3a3a5cb5821c9587fc1281c31fb` |
| Corpus root / manifest hash / corpus file hashes | PENDING owner evidence |
| Automated corpus result | NOT RUN on real external evidence |
| `humanAuditStatus` | `pending` |
| Reviewer / owner role IDs and actual review date | PENDING human review |
| Detached attestation / redacted audit checksums | PENDING signed evidence |
| Corpus freeze | NOT FROZEN |
| Baseline / correction study / usefulness decision | NOT MEASURED |
| Task 4 outcome | `DISABLED_PENDING_EVIDENCE` — closed on the unavailable-evidence branch |
| Task 5 | SKIPPED / BLOCKED by Task 4; no recorder or human baseline sessions created |
| Task 6 outcome | `disabled` — manual-only smart-mask disposition; no algorithm amendment |

The [human checklist](smart-mask-evidence-checklist.md) and existing
[annotation protocol](../superpowers/plans/room-recolor-annotation-protocol.md)
are binding. A release verifier PASS requires exact corpus and adjudication
validation plus an approved detached human audit bound to the same hashes.
Automated validation cannot prove provenance, independence, actual identity,
blindness, permission truth, or absence of near duplicates. Human reviewers must
reject false assertions even when structure and hashes pass.

Task 4 did not run the guarded real-corpus verifier: no absolute owner-supplied
corpus root or approved signed audit is available. There is no invocation,
stdout, exit code, manifest hash, or file hash for real evidence to report; this
is an unavailable gate, not a verifier PASS or a fabricated failed run. The human
checklist remains unsigned and `humanAuditStatus` remains `pending`.

Task 5 is explicitly skipped because Task 4 did not produce
`FROZEN_FOR_AMENDMENT`. The 8-participant/48-session manual baseline is also
unavailable. No baseline schedule, session, metric, participant, study signature,
or manual-correction recorder is invented. `DISABLED_PENDING_CORRECTION_STUDY`
would apply only after a real corpus freeze if the human study remained missing;
the current primary disposition stays `DISABLED_PENDING_EVIDENCE`.

Task 6 closes only the safe disabled branch. No candidate, algorithm amendment,
connectivity/edge/depth/cleanup/seed/abstention constants, production enable
switch, dependency, or smart quality/usefulness claim is authorized or added.
Manual Add/Erase/Undo/Redo and the existing offline Manual Mask flow remain the
release path. This disposition does not assert an overall release, device gate,
or full-suite pass. The incomplete conditional work remains in the detailed
[improvement backlog](../improve/plan-04-smart-mask-incomplete.md).

## Verification and limits

One lightweight repository source/copy scan on 2026-10-28 checked `lib`,
`assets`, `README.md`, and `docs/release` for Smart control/correction labels and
availability/service references. At scan time its only matches were release
gate documentation; no app/asset/README Smart labels matched. A repository path
inventory found no actual store draft, marketing, screenshot, or ad artifacts
to inspect. The scan log is
`.superpowers/sdd/2026-10-27-tintatlas-smart-mask-conditional/task-4-6-source-claim-scan.log`.
Task 3's concurrently prepared boundary/visibility behavior is assessed by its
own focused tests and report; this scan does not certify later source changes,
visual screenshots, external store consoles, or future ads. Release preparation
must inspect the exact eventual app/store/screenshot/ad artifacts and keep smart
controls and claims absent. No full Flutter suite, native build, or repeated
passing suite was run for this documentation closure.

## Owner actions to reopen the conditional path

1. The product owner supplies or commissions the exact 24 lawful real photos,
   retained source/working bytes and permission trail, two independent blind
   human submissions per photo, and third-human adjudication required by the
   [checklist](smart-mask-evidence-checklist.md). Downloaded photos alone, AI or
   synthetic images/maps, model output, or developer self-scoring cannot replace
   lawful provenance, independent people, adjudication, or human sessions.
2. The acquisition reviewer and product owner actually review and sign the
   owner-held attestation. Record redacted role IDs, actual review date, decision,
   attestation checksum, and approved audit JSON bound to the manifest/protocol
   hashes. Keep names, contacts, signatures, and private evidence out of tracked
   files. Record the absolute owner-supplied corpus/audit paths in the ledger and
   archive the guarded release command, output, exit code, and hashes:

   ```sh
   dart run tool/verify_room_recolor_benchmark.dart \
     --root <absolute-owner-corpus-root> --require-adjudicated \
     --human-audit <absolute-owner-redacted-audit-json>
   ```

   Only an actual exit 0 / `status: PASS` plus approved human audit can record
   `FROZEN_FOR_AMENDMENT`; preserve the pinned protocol and immutable evidence.
   Any corpus/protocol byte change invalidates the freeze and audit.
3. After that gate passes, implement the separately gated offline recorder,
   freeze the manual schedule before sessions, score the untouched MOSAIC/Manual
   Mask baseline with the frozen loader/metrics, and pass
   `validateRoomBaselineSuitability`. Study operations must obtain consent and
   conduct 8 people × 6 rooms = 48 completed sessions, two different people per
   photo with counterbalanced order. Freeze schedule/report/final-mask hashes,
   device/build IDs, monotonic timings, quality, and separate exclusions/dropouts
   with signed operational evidence. Unavailable sessions keep production disabled.
4. Only after Tasks 4–5 genuinely pass may a separately reviewed, product-owner
   approved amendment identify independent calibration evidence, fixed constants,
   device/timeouts, production binding, rollback and preregistered comparison.
   Execution then still requires all safety/reversibility gates, an improved
   median correction time, mean IoU delta >= -0.01, leakage delta <= 0 and a
   valid assisted study passing `SmartMaskDecision.evaluate`. The 25% time/10%
   leakage stretch targets never replace mandatory gates. Missing/invalid data
   remains `insufficientEvidence`, not approval to enable.
