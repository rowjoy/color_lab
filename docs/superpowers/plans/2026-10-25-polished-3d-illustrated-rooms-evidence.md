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

## Final six-room evidence — 2026-10-25

Task 7 changes only encoder acceptance tests, the preview harness, this evidence
and README. The six completed SVGs and all production UI/domain behavior stay
unchanged. The objective_c package root was checked before Flutter and remains
the approved `objective_c_no_hooks/` redirect. Every Flutter command below used
`/usr/bin/sandbox-exec -f tool/deny-native-compilers.sb
/Users/jamirulislam/Applications/flutter/bin/flutter` with `--no-pub`.
The outer sandbox initially rejected `sandbox_apply` (exit 71); execution then
used approved escalation while retaining that inner compiler-denying guard.
No dependency fetch, clean, native build, install or physical-device check ran.

### Measured final complexity and timing

These are the six sorted `assetMetrics` records in
`build/previews/illustrated-room-render-manifest.json`:

| Room ID | UTF-8 bytes | Geometry | Gradients | Clip paths |
| --- | ---: | ---: | ---: | ---: |
| bathroom | 15189 | 145 | 6 | 0 |
| bedroom | 14112 | 117 | 5 | 0 |
| dining | 14077 | 129 | 4 | 0 |
| kitchen | 13739 | 134 | 5 | 0 |
| living | 15847 | 138 | 6 | 0 |
| study | 21279 | 190 | 7 | 0 |

All assets remain below 81920 bytes and 400 simple geometry elements. No
complexity exception or filler geometry is needed. The identical timed
six-room grayscale/colored catalog contract shown in the untouched baseline
passed 6/6: `real 2.56`, `user 2.76`, `sys 0.48`, versus baseline
`2.59 / 2.63 / 0.54`. It ran without another Flutter verification command in
parallel. Elapsed time is 0.03 seconds lower (about 1%); these single host
measurements show no material elapsed regression and establish no device claim.

### Acceptance and preview results

The expected-name change was run before implementing the eight new captures.
Observed RED: the six existing preview scenarios passed, then teardown failed
because the actual set had 19 names and lacked six stress images, whole-room
phone and the real Study export (first reported missing: Living stress).
After adding those captures, the combined encoder/preview run passed 17/17.
The six real encoder cases protect literal PNG signatures, 2400×1600 size,
four common editable anchors, every room-specific Furniture anchor and one
fixed authored-detail pixel per room; the previous error/disposal cases remain.
These acceptance tests exercise the completed assets and real encoder directly.

The final eight focused room suites passed **156/156**: SVG, polish, gallery,
editor, integration, navigation, artwork encoder and export controller. The
standalone preview command passed **7/7**, without renderer exceptions:

```sh
/usr/bin/sandbox-exec -f tool/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub tool/render_illustrated_room_previews.dart --reporter expanded
```

The manifest contains exactly **27 unique expected PNG names**, with exact
captured-set equality and duplicate detection. An independent disk check
confirmed every expected file exists, has a PNG signature, and all 18 canonical
artworks plus the real export are 2400×1600. The manifest describes files from
this invocation; unrelated preview outputs may coexist in `build/previews/`.
Its set is six rooms × grayscale/recommended/stress (18), gallery phone/tablet
(2), phone rail closed/open/focus/whole-room (4), landscape (1), tablet (1) and
the real Study export (1). Files and room metrics are sorted.

Stress Wall/Ceiling/Floor/Furniture are exactly
`#F4EEE4 / #20242C / #0057FF / #FF4D00`. The phone harness exits focus, taps
`room-view-full`, settles and asserts `IllustratedRoomSvg.fit == BoxFit.contain`
before capture. The real Study export calls `SvgIllustratedRoomArtworkEncoder`
directly with the recommended draft, decodes/asserts 2400×1600 and writes the
returned bytes directly. UI export fakes remain isolated to the UI harness;
no Gallery channel or user-document write occurs.

### Visual review

Inspected all 27 outputs on two labelled contact sheets, every recommended
artwork individually at large size, central portrait crops of all six rooms,
the phone whole-room image and the real export individually. Canonical artworks
were reviewed at card scale as well as larger source scale. The shared
mountain/sun visual language remains visible in several windows and pictures;
the complete window/art/pendant/plant compositions differ by room rather than
repeating one complete layout.

| Room | Light, shadows and material/crop review |
| --- | --- |
| Living | Upper-left window light and lower-right sofa/chair/table/console casts agree. Curved arms, seams, compression and table thickness survive grayscale/card scale. Orange stress upholstery keeps its hue and neutral form; the central sofa/table crop identifies a lounge. One broad picture, TV, floor lamp and left planter distinguish the layout. No distorted furniture or detail noise observed. |
| Bedroom | Left daylight and local bedside pools ground the bed, side tables and wardrobe with fitted lower-right shadows. Mattress depth, duvet folds, pillow volume and timber reveals remain distinct in grayscale. Orange bedding/furniture stays readable; the central bed/headboard crop identifies the room. Paired art, high pendant and wardrobe differ from the lounge/study arrangement. No distorted furniture or card-scale noise observed. |
| Study | Upper-left daylight, warm task pool and lower-right desk/chair/shelf shadows agree. Desk reveals/grain, shaped upholstery and monitor reflections remain distinct without extra color controls. Orange stress bases retain hue; grayscale keeps form. The central monitor/desk/chair crop identifies a study; recessed window, paired art, bookshelf and two plants make its own arrangement. No distorted furniture or fine noise observed. |
| Dining | Left daylight plus the low central pendant pool agree with fitted table/chair/sideboard casts. Foreshortened top, thick edges and overlapping chair sizes remain readable in grayscale and orange stress. The narrow central crop still shows dining chairs, table and place setting. Angled architecture, low pendant and right vase/sideboard distinguish its composition despite shared art motifs. No distorted furniture or card-scale noise observed. |
| Kitchen | High central window light and restrained under-cabinet pools agree with cabinetry/island grounding. Bevels, recessed doors, toe-kicks, stone marks and fixed appliances separate materials. Orange cabinetry remains recognizable over blue stress floor; grayscale retains island depth. The central sink/island crop identifies a kitchen. Its centered triptych window, no wall pictures/pendant and left counter plant form a distinct layout. No distorted furniture or fine noise observed. |
| Bathroom | Upper-right clerestory/reflected light and lower-left fixture casts agree. Tile/grout, glass edges, mirror, chrome and curved sanitary ware separate hard materials while vanity/storage share one editable hue. Orange stress cabinets remain distinct; grayscale retains recesses and contact depth. The central basin/vanity crop identifies a bathroom. Clerestory, shower, large mirror and linen storage are unique in the set. No distorted furniture or card-scale noise observed. |

Phone/tablet gallery cards retain recognizable grayscale rooms. Portrait fill
and focus show the Study's central desk/chair; whole-room mode exposes
the window and side seating alongside the desk and central chair, with expected
letterboxing. The open color rail obscures the right shelving. The rail and
looks flyout remain legible. Landscape and tablet preserve the recommended
Study's material details. The real 2400×1600 export contains the complete
artwork with no editor controls or crop loss. This review establishes local
source/test rendering only.

### Whole-project verification limits

The exact final test/harness files were unchanged during the complete run:

```sh
/usr/bin/sandbox-exec -f tool/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub --reporter expanded
/usr/bin/sandbox-exec -f tool/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter analyze --no-pub
```

Full-suite result: **exit 1, 1507 passed / 38 failed, 01:05**. Compared literal
relative file/test-name pairs against Task 6's exact-final baseline
(`/tmp/task6-exact-final-full.log`): **38 baseline / 38 final unique failures;
added `[]`, resolved `[]`, room failures `[]`**. The baseline has one duplicate
error-line emission; comparison counts unique test identities and agrees with
the runner's 38-failure summary. All failures remain in Games/profile tests and
their matching-game integration dependency. The full suite is not all-pass.
The ignored Task 7 workflow report enumerates all 38 failing test identities.

Both whole-project analysis invocations exited 1 with the same single info:
`lib/features/games/presentation/fruit_pop_screen.dart:1048:58`,
`unnecessary_brace_in_string_interps` — "Unnecessary braces in a string
interpolation". That file is unchanged from the Task 7 base commit. No room or
changed-file analysis issue was reported; whole-project analysis is not clean.
These unrelated baseline failures/info were preserved as required.

The two changed Dart files pass the formatting check and `git diff --check`
passes. Only the four scoped shipping files are included in Task 7's commit;
generated PNGs/manifest, contact sheets, logs and workflow reports are excluded.
