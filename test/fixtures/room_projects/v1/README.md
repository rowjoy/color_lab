# Frozen Room projects v1

These immutable, non-personal bytes were independently assembled against schema v1 at `4d98b1604d6901086035dd8eb7af26b61ced824f`, using Python standard-library JSON, SHA-256 and PNG/zlib assembly. No current Dart encoder runs to create these fixtures during tests. Plan 03 must consume these exact bytes, not regenerate them with a newer encoder.

`inventory.json` pins every relative path, byte length and SHA-256. The two projects share visually identical 3 × 2 synthetic corner-color pixels, with separate project-owned assets. Pixel rows are red/green/blue and yellow/cyan/magenta. No EXIF/GPS/text is present.

- `v1-healthy` / `v1-healthy-photo`: three acknowledged metadata revisions, created `2026-10-27T01:00:00.000Z`, updated 02:00/03:00/04:00 UTC. AI labels `[1,1,0,4,3,0]`, current `[1,2,0,4,3,1]`, mask revision 2, color revisions 1/2/3. Variant `a` Warm (`#CC8844` wall, `#EEEEEE` ceiling); `b` Cool (`#2255AA` wall, `#102030` floor). Revision 3 selects `b` and pins `a`; all three reuse exact photo/mask/1 × 1 thumbnail references.
- `v1-manual` / `v1-manual-photo`: revision 1, created 01:00 and updated 02:00 UTC; all-zero AI, current `[0,1,0,0,0,0]`, mask/color revisions 1, active `a`, no comparison baseline, null thumbnail. The fixture name is provenance only: schema v1 cannot establish why the AI result was empty after reopen.

Pointers are checksummed and authorize contiguous ancestry only. Recovery tests corrupt owned copies and create an unacknowledged newer revision; the frozen source files remain untouched. This proves process-interruption recovery, not directory durability through device power loss. Storage-v1 PNG support is broader than strict export PNG support.

For deterministic ten-project storage diagnostics, populate five independent copies of each snapshot through the repository with IDs `budget-01` through `budget-10` and photo IDs `budget-photo-01` through `budget-photo-10`, fixed timestamps above, no additional revisions. This tiny synthetic recipe is a protocol/storage floor, not representative phone storage or a performance result. Mobile Performance QA owns realistic 1600-axis prepared-photo fixtures and fresh/populated app-storage measurements on named supported devices.
