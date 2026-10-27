# TintAtlas identity decision

**Recorded:** 2026-10-27

**Scope:** working identity and immutable-store-ID gate for Plan 01

**Decision state:** blocked before package-ID, icon, signing, domain, or store-metadata lock

## Frozen working identity

| Field | Current repository value | Working proposal | Gate |
| --- | --- | --- | --- |
| Product/store title | `Color Lab` on Android and iOS | `TintAtlas: Room Visualizer` | May be used as an internal working name; public asset/store lock is blocked by the brand screen below. |
| Dart package | `color_lab` | Keep during Plan 01 | Renaming the Dart package is not required for the user-facing brand and would create avoidable churn. |
| Android namespace/application ID | `com.example.color_lab` | `com.roomvisualizer.tintatlas` | Do not apply until `newListing: true` and brand acceptance are evidenced. |
| iOS bundle ID | `com.example.colorLab` | Candidate `com.roomvisualizer.tintatlas` | Do not apply until the same gates pass and the Apple identifier is available to the owner. |
| Version | `1.0.0+1` | No change in Task 1 | Release numbering is reconciled later against store/signing history. |

The existing Android/iOS identifiers and release signing configuration are development-only and are not publishable decisions. The proposed reverse-DNS identifier is a candidate, not a reservation.

## Immutable publication-history gate

`newListing: blocked`

- Owner: Google Play Console/App Store Connect account owner.
- Required evidence: written attestation plus console screenshots showing whether this product, either current identifier, or any prior signed public build has listing/install history.
- If the evidence says **true**, a new approved application/bundle ID may be established before the first production artifact.
- If the evidence says **false**, retain the existing production identity and write an upgrade/data-compatibility plan before changing identifiers.
- Repository contents, public store search, and local debug/release builds cannot prove this fact.

No later task may convert `newListing` to `true` by inference. Task 9 must leave package IDs unchanged while this gate is blocked.

## Preliminary brand screen

`brandNameClearance: blocked`

This screen is product research, not professional legal clearance.

Evidence captured on 2026-10-27:

- An exact-name web conflict exists: [tintatlas.com](https://tintatlas.com/) is live, and its [public site API](https://tintatlas.com/wp-json/) identifies the business as “Tint Atlas” with a window-film/tint description. That field is adjacent enough to color/tint visualization to require a deliberate accept-or-rename decision.
- The official [Verisign RDAP record](https://rdap.verisign.com/com/v1/domain/tintatlas.com) reports `TINTATLAS.COM` active, registered 2026-06-07 and expiring 2027-06-07.
- A [Google Play US search](https://play.google.com/store/search?q=TintAtlas&c=apps&hl=en&gl=US) showed no exact app result at the time of the screen.
- An [Apple US Search API query](https://itunes.apple.com/search?term=TintAtlas&entity=software&limit=200) returned fuzzy results but no exact `TintAtlas` app title at the time of the screen.
- Exact store-name absence is not trademark clearance. [USPTO search guidance](https://www.uspto.gov/trademarks/search) calls for similar-mark searching and a comprehensive clearance search.

Owner: product owner, with trademark professional input where appropriate. Required evidence: documented target-market search and a written **accept TintAtlas** or **rename before publication** decision. Until then, do not purchase/lock brand assets or publish store metadata under this name.

## Brand-neutral content rule

TintAtlas must not include Asian Paints or another manufacturer's branding, proprietary shade catalogue, shade codes, copied editorial text, imagery, or product claims. Bundled palettes use original generic names and standard color values with source/license records.

## Sign-off record

| Gate | State | Sign-off needed from | Evidence location |
| --- | --- | --- | --- |
| Working title for implementation | accepted by approved product spec | Product owner | Approved full-product design, section 2 |
| Exact-name conflict disposition | blocked | Product owner / clearance reviewer | Add dated decision to this file |
| `newListing` | blocked | Store-account owner | Add attestation and console evidence reference |
| Android application ID | blocked | Product owner + Android release owner | Record after both gates above pass |
| iOS bundle ID | blocked | Product owner + iOS release owner | Record after both gates above pass |
| Production signing | blocked | Platform release owners | Later release ledger; credentials never enter this repository |

## Task 9 gate amendment — 2026-10-27

Task 9 rechecked both prerequisites before changing platform identity or
installing locked public brand assets. `newListing` remains `blocked`, and
`brandNameClearance` remains `blocked`. Therefore this branch intentionally
retains the current Android/iOS application identifiers, signing setup,
launcher icons, and public splash assets.

No repository inference can satisfy either gate. Resuming Task 9 requires:

1. the store-account owner's written new-listing attestation with the Google
   Play Console/App Store Connect evidence reference; and
2. the product owner's dated accept-or-rename decision for the recorded
   TintAtlas exact-name conflict.

This amendment records a safety stop, not approval of the current development
identifiers for publication.
