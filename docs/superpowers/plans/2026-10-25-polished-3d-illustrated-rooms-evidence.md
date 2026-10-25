# Illustrated-room source-render evidence

These are local source-render measurements, not device benchmarks.

## Untouched baseline — 2026-10-25

The approved `objective_c_no_hooks` redirect was confirmed before Flutter.
Case-insensitive simple-geometry counts include only path, rect, circle,
ellipse, polygon, polyline and line.

| Asset | UTF-8 bytes | Geometry |
| --- | ---: | ---: |
| Living | 8873 | 92 |
| Bedroom | 9331 | 99 |
| Study | 11547 | 125 |
| Dining | 6964 | 76 |
| Kitchen | 7138 | 76 |
| Bathroom | 7137 | 74 |

Command, run before any asset changes:

```sh
/usr/bin/time -p /usr/bin/sandbox-exec -f tool/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/features/room_studio/presentation/illustrated_room_svg_test.dart --plain-name "satisfies the catalog-wide render contract" --reporter expanded
```

Result: `+6: All tests passed!`; `real 2.59`, `user 2.63`, `sys 0.54`.
The outer restricted sandbox initially prevented `sandbox_apply`; the same
command succeeded with sandbox escalation while retaining the checked-in
native-compiler-denying sandbox.

## Study pilot — 2026-10-25

Study is now 21,279 UTF-8 bytes, 190 simple geometry elements, 7 local
gradients and 0 clip paths. The other five assets remain at their untouched
values above. The Study stays below both review targets without a complexity
exception.

The same six-room render-contract command passed all 6 tests with a quiet
measurement of `real 2.52`, `user 2.69`, `sys 0.49`. An earlier simultaneous
full-suite run yielded `real 5.12`, `user 4.36`, `sys 1.09`; the quiet rerun
resolved that contention. These individual local timings do not establish
device performance or a statistically meaningful speed difference.

Study polish plus existing SVG contracts: 62/62 passed. Deterministic preview
scenarios: 6/6 passed; manifest: 19 files, 19 unique names. Final repository
suite: 1,487 passed, 38 failed; all failures match the known Games/profile
baseline, including its color-test integration dependency. No room test failed.

Visually inspected the generated Study grayscale and recommended images at
2400 × 1600 source size and 360 × 240 thumbnail size. The pilot has recessed
drawers and shelving, shaped upholstery, local warm desk light, upper-left
daylight, monitor reflections and fitted lower-right contact shadows. A planter
overlap found during review was corrected by placing it on the floor behind the
reading chair. Exact surface/furniture anchors and the authored sky decoration
sample remain unchanged. No raster reference is embedded or shipped.
