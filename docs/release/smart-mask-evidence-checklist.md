# Smart-mask external evidence checklist

Task 4 outcome (2026-10-28): **DISABLED_PENDING_EVIDENCE**. No owner-supplied
corpus or signed human audit was received; the gate closes on the unavailable
branch. Production remains `disabledByEvidence`. Task 5 is skipped/externally
blocked and Task 6 takes the manual-only closure with no algorithm amendment.

Audit status: **PENDING**.
This is an unsigned review checklist, not an attestation. EXTMASK-01 and MASK-09
remain open. Never fill absent evidence with synthetic photos/maps, model output,
developer self-scoring, invented people, dates, or signatures. Downloading real
photos alone also cannot establish lawful provenance, independent annotations,
adjudication or human correction sessions. No unchecked item below is satisfied
by Task 1/2 tooling tests or this closure.

Use the unchanged [annotation protocol v1](../superpowers/plans/room-recolor-annotation-protocol.md).
The normative protocol artifact SHA-256 is
`9bb3b0f379054af42598deebb4cc8a90e1a3e3a3a5cb5821c9587fc1281c31fb`.
A protocol change requires a separate version and benchmark.

The guarded release command has **not been run against real external evidence**:
there is no absolute owner-provided corpus root or approved audit JSON. No
real-corpus command result, freeze hash, reviewer ID, signature, or review date
has been fabricated. The date above records the documentation decision, not a
human audit date. See the [decision and owner reopening actions](smart-mask-decision.md)
and [detailed backlog](../improve/plan-04-smart-mask-incomplete.md).

The acquisition reviewer and product owner complete and sign a detached,
owner-held attestation only after visually inspecting the photos, licenses,
people records, and submission process. Keep raw legal names, contact details,
identity verification, permissions, submission receipts, and signatures in that
private evidence archive. Tracked records retain redacted role IDs, decision,
review date, hashes, and the external attestation checksum only.

- [ ] Inspect exactly 24 distinct real indoor photographs: six living-room,
  six bedroom, six kitchen-dining, six other-indoor. Review representativeness.
- [ ] Visually confirm every required scene/protection/lighting tag across the
  set: people, windows, doors, wall-decoration, furniture-touching-walls,
  low-contrast, patterned, daylight, artificial-light, shadows, reflections.
- [ ] Verify explicit lawful redistribution permission for each actual photo,
  creator/title, exact source URL and immutable revision, license ID/version/URL,
  acquisition UTC date, and full detached permission/license text. Archive the
  actual acquisition trail and confirm it applies to the retained source bytes.
- [ ] Review decoded duplicates and crops/rescales/near duplicates by sight.
  Retain Daderot CC0 at most once; exclude the unresolved Unsplash photo.
- [ ] Verify each opaque oriented working image faithfully derives from its
  retained source; confirm protocol dimensions/byte limits and coordinate system.
- [ ] Independently verify two different actual annotator identities and the
  stable role-ID mapping. Retain both original submissions unchanged and their
  real UTC receipts; identity strings alone do not establish two people.
- [ ] Verify independence and blindness: each annotator saw only the same
  working image/instructions, with no models, predictions, candidate previews,
  other submission, or adjudicated map. Preserve evidence of the process.
- [ ] Verify the third actual adjudicator differs from both annotators, received
  both sealed submissions before review, and recorded the real adjudication time.
- [ ] Verify all six detached maps and adjudication JSON, combined submission
  hashes, original A/B preservation, and adjudicated maps. Review every ownership
  or protection dispute exactly once with explanations matching final bytes;
  agreed pixels stay unchanged. Shared errors require fresh blind submissions.
- [ ] Confirm all four paintable layers across the corpus and protected ground
  truth in every image; visually inspect semantics, boundaries, and thin gaps.
- [ ] Run the guarded inspection, review every reported file/decoded hash,
  archive command/stdout/stderr/exit code, then bind the signed human audit to
  the exact validated manifest and pinned protocol hashes.
- [ ] Hash the detached signed attestation and retain it privately. The human
  reviewer and owner authorize the recorded decision and review date; do not
  infer approval from an automated PASS.
- [ ] Run release mode with the approved redacted audit, archive both report and
  audit checksums, and copy only hashes/audit metadata into the release ledger
  before tuning. Any corpus/protocol change invalidates the freeze and audit.

The verifier checks structure, exact counts, checksums, byte domains, recorded
identity distinctions, chronology and complete dispute coverage. **Automated
validation cannot prove provenance, license truth, real identities, independence,
blindness, faithful derivation, tag correctness, or all near duplicates.** A false
or non-independent submission fails this human review even if JSON validates.

Inspection command (cannot freeze evidence):

```sh
dart run tool/verify_room_recolor_benchmark.dart --root <absolute-owner-corpus-root>
```

Release command (exit 0 and `status: PASS` require both gates):

```sh
dart run tool/verify_room_recolor_benchmark.dart \
  --root <absolute-owner-corpus-root> --require-adjudicated \
  --human-audit <absolute-owner-redacted-audit-json>
```

The detached redacted JSON must contain `humanAuditStatus: "approved"`,
`decision: "FROZEN_FOR_AMENDMENT"`, exact `manifestSha256` and `protocolSha256`,
actual `reviewedAt` (UTC ISO-8601 ending Z), `acquisitionReviewerRoleId`,
`productOwnerRoleId`, and `externalAttestationSha256` (64 lowercase hex).
Role IDs use ASCII letters/digits/hyphens/underscores and start with a letter or
digit. These are archive lookup IDs, never legal names or contact information.
No approved example is supplied because the human evidence is unavailable.

The report exposes `humanAuditStatus`, the audit JSON checksum, selected audit
metadata, manifest/protocol checksums, sorted root-relative `fileSha256` entries
for every validated license/source/working/six-map/adjudication file, both decoded
RGBA hashes per photo, categories and tags. No photo bytes or annotator personal
details are echoed. Missing approval in release mode exits 1; without an audit,
a validated release corpus reports `PENDING HUMAN AUDIT`. Inspection always says
`INSPECTION ONLY`, even with complete maps. `baselineSuitability` remains
`NOT CHECKED`; these commands do not score a candidate or prove human provenance.
