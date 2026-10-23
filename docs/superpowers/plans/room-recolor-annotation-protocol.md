# Room recolor benchmark: blind annotation protocol v1

Date: 2026-10-22. This is an acquisition and human annotation instruction, not
evidence that a corpus or annotations already exist. Slice 1A supplies tooling
and the frozen scoring contract. Slice 1B must supply the real evidence before
Task 1 can finish or Task 2 can open.

The normative byte artifact is
`test/fixtures/room_recolor/v1/protocol.json`. Its SHA-256 is
`9bb3b0f379054af42598deebb4cc8a90e1a3e3a3a5cb5821c9587fc1281c31fb`.
The loader pins that exact checksum. Do not alter v1 after viewing candidate
output. A rule change requires a separately versioned protocol and benchmark;
do not relabel an altered contract as v1.

## Acquisition and corpus assembly

Acquire 24 distinct real indoor room photographs with explicit redistribution
permission. Use exactly six `living-room`, six `bedroom`, six `kitchen-dining`
and six `other-indoor` images. Include all four paintable layers across the
set. Every annotated image must contain some protected ground truth.

Across the set include all tags: `people`, `windows`, `doors`,
`wall-decoration`, `furniture-touching-walls`, `low-contrast`, `patterned`,
`daylight`, `artificial-light`, `shadows`, `reflections`. Use these tags only
where the visible scene supports them; they are corpus coverage evidence, not
model labels. Acquisition reviewers must check the tags against the photographs.

Retain the Daderot CC0 fixture at most once. Different encodings or crops of the
same photograph are not additional rooms. Do not include the unresolved
Unsplash photograph. The loader rejects equal oriented decoded source RGBA
hashes, including cross-format duplicates. It cannot recognize every crop,
rescale, near duplicate, or false provenance claim; a human acquisition review
must exclude those too.

For every source preserve its exact URL and immutable source/page revision,
creator, title, license identifier/version/URL, acquisition time and full
license/permission text. Confirm permission to redistribute the actual photo,
not just its webpage. Keep source bytes and the oriented opaque prepared
working image. Respect the existing 24 MiB acquisition, 32 MiB processing,
24-million decoded-pixel and 16,384-axis limits; working long edge is at most
1600 pixels. Confirm the working image faithfully derives from its source.

Paths relative to the benchmark root:

```text
protocol.json
manifest.json
licenses/<photo-id>.txt
photos/<photo-id>/source.<ext>
photos/<photo-id>/working.<ext>
photos/<photo-id>/annotations/annotator-a.ownership.bin
photos/<photo-id>/annotations/annotator-a.protection.bin
photos/<photo-id>/annotations/annotator-b.ownership.bin
photos/<photo-id>/annotations/annotator-b.protection.bin
photos/<photo-id>/annotations/adjudicated.ownership.bin
photos/<photo-id>/annotations/adjudicated.protection.bin
photos/<photo-id>/annotations/adjudication.json
```

Manifest schema is an object with integer `version: 1` and a `photos` array.
Each photo contains:

| Field | Required content |
| --- | --- |
| `id` | Unique nonempty ASCII letters/digits/hyphens/underscores, starting with a letter or digit. |
| `category`, `tags` | One category above; nonempty list of distinct supported scene tags. |
| `provenance` | `sourceUrl`, `sourceRevision`, `creator`, `title`, `licenseId`, `licenseVersion`, `licenseUrl`, `redistributionPermitted: true`, `acquiredAt` in UTC ISO-8601 ending `Z`, `licenseText` file reference. |
| `source` | File reference plus positive integer `width`, `height` of oriented decoded source. |
| `decodedRgbaSha256` | SHA-256 of oriented decoded source RGBA bytes in row-major channel order R,G,B,A. |
| `working` | File reference plus positive integer `width`, `height` and `decodedRgbaSha256` of opaque oriented working RGBA. |
| `annotations` | Map with all four evidence entries described below. Omit only during acquisition-only inspection. |

A file reference is an object with `path` (root-relative, no traversal) and
`sha256` (64 lowercase hexadecimal characters of the exact detached file
bytes). Hash license text, source and working files, all six annotation byte
files and the adjudication JSON. Do not substitute a JSON claim for a file.

## Independent annotator instructions

The coordinator provides each of two different humans only the working image
and the layer/protection instructions in this section. They must not see model
predictions, overlays, candidate previews, each other's work or an adjudicated
map. Do not initialize or trace maps from a model. Use the same frozen working
pixels and coordinate system; annotate at full working resolution. Preserve
each original submission without edits or post-adjudication replacement.

Write two headerless row-major unsigned-byte maps, each exactly `width * height`
bytes. The ownership map is exclusive: 0 unselected, 1 Wall, 2 Ceiling, 3 Floor,
4 Furniture. Assign only the visible paintable surface. Ownership cannot overlap.
Use 0 for unsupported objects, uncertain/nonpaintable regions, and protected
objects. For Furniture use visible furniture surface, not a person's clothing
or a decoration resting on it. Mark the actual physical edges at pixel
resolution, preserving thin gaps and occluders; do not expand labels to satisfy
the scoring tolerance.

The separate protection map uses only 0 (unprotected) or 255 (protected). Mark
people, windows, doors, wall decoration and other visible objects that should
not be automatically recolored as protected, even if their color or texture
resembles a supported layer. Use photographed evidence, not model class IDs.
A protected pixel must have ownership 0. At ambiguous edge pixels, decide from
the working image and leave a note for adjudication. This binary ground truth
is independent of any later soft protection matte.

For each submission record the human's stable identity, role (`annotator-a` or
`annotator-b`), actual UTC submission time, `blind: true`, and
`submissionSha256 = SHA256(ownership bytes concatenated with protection bytes)`.
Identical submissions can be legitimate, but still require two humans and two
preserved independent maps. Record the actual time; never invent one.

In `annotations`, each of `annotator-a`, `annotator-b`, `adjudicated` is an object
with integer `width`, `height`, and `ownership`/`protection` file references.
Use the role-specific detached paths shown above. `adjudication` is a file
reference to `adjudication.json`.

## Adjudication and evidence

A third human reviews the two sealed submissions only after both are received.
Compare both ownership and protection maps pixel by pixel. The disputed set is
the union of pixels where either ownership or protection differs. Review every
disputed region against the working image, decide final ownership/protection
and explain the decision. Preserve all original A/B bytes.

The detached `adjudication.json` contains:

- `origin: "human-independent"`.
- `annotators`: exactly the two submission objects with `role`, `identity`,
  `blind`, `submittedAt`, `submissionSha256` as described above.
- `adjudicator`: identity different from both annotators.
- `adjudicatedAt`: actual UTC time ending `Z`, no earlier than either submission.
- `disputes`: array of region objects, each with a nonempty `pixels` array of
  zero-based row-major indices, a nonempty `decision` explanation,
  `ownershipLabel` in 0..4 and `protectionValue` in 0/255. Split a region into
  separate objects if its final labels differ.

Each disputed pixel must appear exactly once. Final byte maps must match the
recorded decisions; pixels where A and B agree must stay unchanged. If a shared
mistake is discovered, return the image for fresh independent submissions before
freezing rather than silently changing agreed pixels. With no disagreements,
use an empty disputes array, retain both independent submissions and record the
adjudicator's review.

The verifier checks provenance structure, checksums, dimensions, literal byte
domains, independence claims, submission hashes/time order and complete dispute
coverage. It cannot prove the named people actually acted independently or that
the license assertion is true. The coordinator must retain the real submission
and provenance audit trail and attest to those facts. Declaring model-generated
or synthetic labels to be human evidence is invalid, even if JSON passes.

## Literal quality scoring

Score ownership per layer. A class-specific inner boundary is a pixel of that
class with at least one of its eight neighbor positions outside that class;
positions outside the image count as background. Precision counts predicted
boundary pixels having any ground-truth boundary pixel of the same class within
Euclidean distance <= 5 working pixels, divided by predicted boundary count.
Recall separately counts matching ground-truth pixels divided by ground-truth
boundary count. Matches are not consumed. F1 is their harmonic mean, or 0 when
only one side exists or no matches exist.

IoU is intersection/union of same-class ownership. Jointly absent layer/image
pairs have null IoU/F1 and are excluded from means. A predicted false-positive
layer with absent ground truth remains included and scores 0. Per-image macros
average its eligible layers. Corpus macro IoU/F1 average eligible layer/image
pairs equally, rather than reaveraging per-image macros. Per-layer means average
that layer's eligible images. An entirely empty eligible set is null.

Leakage uses the supplied final effective recolor coverage bytes, regardless of
ownership labels: every protected pixel with coverage >= 1 is colored. Expose
both raw counts and divide colored protected count by protected ground-truth
count in that image. Zero protected denominator is undefined (null), not zero;
the real annotated loader rejects any such image. Macro leakage is the
unweighted mean of defined per-image ratios, never a pooled pixel ratio.

Before tuning, score the frozen current MOSAIC baseline with the same decoded
working pixels, target colors and settings used for all candidates. Call
`validateRoomBaselineSuitability` on those scores. A baseline with zero aggregate
leakage fails suitability: it cannot demonstrate a 10% relative reduction.
The corpus verifier does not invent or run this separate baseline evidence.

The later LAB percentile rule is `floor(p * (n - 1))` only. It does not define
quality-metric percentiles, matching, averaging or alternate boundary tolerance.

## Freeze gate

Run the guarded direct verifier with `--require-adjudicated`. A successful run
must accept exactly 24 distinct permitted rooms with complete human evidence.
Record manifest/protocol/source/working/annotation hashes and command results
in the progress ledger before any candidate tuning. Acquisition-only loading is
an explicit inspection mode and cannot open Task 2.

If actual licensed corpus evidence or either human submission/adjudication is
unavailable, report `BLOCKED/PENDING EVIDENCE`. Do not generate substitutes or
begin Task 2. Source tests and synthetic temporary corpora prove tool behavior;
they do not establish benchmark accuracy or genuine human ground truth.
