# TintAtlas size, dependency, and performance budgets

**Recorded:** 2026-10-27

**Baseline host:** Apple M3 Pro MacBook Pro (`Mac15,6`), 18 GB RAM, macOS 26.6.2

**Important:** host/build measurements are not substitutes for named supported-device measurements.

## Measured baseline and guards

| Metric | Current evidence | Guard / decision | State |
| --- | --- | --- | --- |
| Locked packages | 134 total: 16 direct main (15 non-SDK runtime), 2 direct dev, 116 transitive | Default budget is 0 unplanned runtime additions. Each approved addition needs license, privacy/data, security, maintenance, and binary-size review. | active engineering guard |
| Universal Android release APK | 85,949,904 bytes (81.968 MiB), SHA-256 `932f2c808c02c77317f61a42dba0675063548ea1697f175ec5da79a2c39478dd` | Interim alert at more than +5% versus this exact baseline (90,247,399 bytes). This is not a Play download/install-size limit; replace it with AAB device-delivery evidence before release. | measured; threshold proposed pending Release Engineering approval |
| Universal Android debug APK | 185,583,606 bytes (176.986 MiB), SHA-256 `66b9d87a0aa9ca3ca9b830ed1bd328f587ed1c88c572e820271330823144bd4e` | Diagnostic only; never use it for store-size claims. | measured |
| Downloaded Room models | 68,316,288 bytes (65.151 MiB) aggregate | Current exact-byte ceiling is the two pinned files; any increase needs measured benefit, download/storage UX review, and approval. | active compatibility guard |
| Encoded photo input through camera/gallery picker | 24 MiB maximum | Retain the reachable end-to-end limit unless device-memory evidence supports a reviewed change. | active product guard |
| Lower-level photo processor input | 32 MiB maximum | Defense-in-depth ceiling for non-picker callers; it does not raise the user-facing 24 MiB picker limit. | active product guard |
| Decoded photo geometry | 24,000,000 pixels; maximum axis 16,384 | Retain; reject before unsafe decode/allocation. | active product guard |
| Working/palette axes | 1,600 / 200 pixels | Retain as current processing limits; export claims must match actual resolution. | active product guard |
| Mask undo history | 20 commands and 16 MiB | Retain until correction-workflow/device-memory evidence approves a new bound. | active product guard |

The release APK is a release-mode engineering build signed with the repository's debug signing configuration. It proves compilation and provides a repeatable byte baseline; it is not a signed store candidate. The two TFLite models are downloaded separately and are not inside either APK.

## Required measurements still blocked

No number is approved merely because it sounds reasonable. Each row remains blocked until its owner records the named device, build mode, procedure, sample count, raw results, p50/p95 where applicable, and an approved threshold.

| Metric | Baseline | Threshold | Owner / unblock evidence |
| --- | --- | --- | --- |
| Android AAB delivered download/install size per ABI/density | blocked | blocked | Release Engineering: production-shaped AAB and Play bundle/device report |
| iOS archive/IPA and installed size | blocked | blocked | iOS Release: production-shaped archive/export and App Store size report |
| Cold-start first frame | blocked | blocked | Mobile Performance QA: profile/release traces on AND-LOW-24, AND-CUR-36, IOS-MIN-13 or approved replacement, and IOS-CUR |
| Ten real-room projects: database + photos + masks + thumbnails | blocked because the Room project schema/fixture is not implemented | blocked | Plan 02 storage owner creates the fixed ten-project fixture; Device QA measures fresh versus populated app storage |
| Peak RSS: startup, model load, inference, recolor, export | blocked | blocked | Device Lab captures platform memory traces on the minimum-RAM Android and required iPhone/iPad |
| Current device model-inference latency | blocked | blocked | Device Lab; warm/cold p50/p95 with exact model hashes |
| Recolor and PNG export latency | blocked | blocked | Device Lab; fixed photo/mask fixture and named devices |
| Scrolling/frame stability, heat, and battery | blocked | blocked | Device Lab; repeatable scenario/duration plus platform traces |

The current machine had no usable iOS simulator/device session during this baseline and no iOS artifact was built, so Android results must not be copied into iOS rows.

## Latency requirements already accepted by the product spec

- Manual mask-brush feedback: under 100 ms on named supported devices.
- Conditional smart-proposal p95: approximately 1 second.
- Conditional committed-preview p95: approximately 1.5 seconds.

These are gates, not current results. Smart timings apply only if the conditional smart-mask feature is exposed. The recorded 262.686 ms Room-service run is a historical host diagnostic on the baseline Mac; it is neither a phone baseline nor a launch claim.

## Measurement protocol

1. Use profile/release builds with exact commit, platform version, device model, RAM, free storage, model hash, fixture hash, and thermal state recorded.
2. Warm up separately from cold-start/model-download scenarios; do not mix samples.
3. Retain raw timings and report median plus p95 for interactive latency; report peak and steady-state memory separately.
4. Compare against this baseline and explain every dependency/artifact increase.
5. A failed or unmeasured gate narrows/blocks the relevant release or feature; it never becomes a guessed pass.
