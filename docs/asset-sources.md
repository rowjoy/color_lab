# Offline asset sources

All runtime font and color-name data is bundled locally. These files were acquired on 2026-10-21; the immutable revisions below, rather than moving branch URLs, identify their contents. Fonts and licenses are unmodified upstream files; the font filenames were simplified locally.

## Fonts

Both fonts come from the [Google Fonts repository](https://github.com/google/fonts/tree/47d54ca1ebb14fd864695f1d39dc734f39017c33), pinned at commit `47d54ca1ebb14fd864695f1d39dc734f39017c33`.

| Local file | Exact download source | License |
| --- | --- | --- |
| `assets/fonts/PlusJakartaSans-Variable.ttf` | [PlusJakartaSans[wght].ttf](https://raw.githubusercontent.com/google/fonts/47d54ca1ebb14fd864695f1d39dc734f39017c33/ofl/plusjakartasans/PlusJakartaSans%5Bwght%5D.ttf) | SIL Open Font License 1.1 |
| `assets/licenses/PlusJakartaSans-OFL.txt` | [Original OFL.txt](https://raw.githubusercontent.com/google/fonts/47d54ca1ebb14fd864695f1d39dc734f39017c33/ofl/plusjakartasans/OFL.txt) | Copyright 2020 The Plus Jakarta Sans Project Authors |
| `assets/fonts/JetBrainsMono-Variable.ttf` | [JetBrainsMono[wght].ttf](https://raw.githubusercontent.com/google/fonts/47d54ca1ebb14fd864695f1d39dc734f39017c33/ofl/jetbrainsmono/JetBrainsMono%5Bwght%5D.ttf) | SIL Open Font License 1.1 |
| `assets/licenses/JetBrainsMono-OFL.txt` | [Original OFL.txt](https://raw.githubusercontent.com/google/fonts/47d54ca1ebb14fd864695f1d39dc734f39017c33/ofl/jetbrainsmono/OFL.txt) | Copyright 2020 The JetBrains Mono Project Authors |

The font creators' repositories are [tokotype/PlusJakartaSans](https://github.com/tokotype/PlusJakartaSans) and [JetBrains/JetBrainsMono](https://github.com/JetBrains/JetBrainsMono). The shipped files are normal/upright TrueType variable fonts. Plus Jakarta Sans has a `wght` axis from 200 to 800; JetBrains Mono has a `wght` axis from 100 to 800. Both default to 400. Register the local family names as `PlusJakartaSans` and `JetBrainsMono` respectively.

## Color names

`assets/data/color_names.json` is the complete, unmodified `package/dist/colornames.json` from the upstream author's published `color-name-list` version `14.71.1`, downloaded from the [official npm release tarball](https://registry.npmjs.org/color-name-list/-/color-name-list-14.71.1.tgz). Its [registry metadata](https://registry.npmjs.org/color-name-list/14.71.1) records source commit `61eacc60cf6c5491aa423b3d7186c70e6a25b2b8` in [meodai/color-names](https://github.com/meodai/color-names/tree/61eacc60cf6c5491aa423b3d7186c70e6a25b2b8).

The source repository tracks its complete list as [src/colornames.csv](https://raw.githubusercontent.com/meodai/color-names/61eacc60cf6c5491aa423b3d7186c70e6a25b2b8/src/colornames.csv) and generates the published JSON during its build; the JSON is therefore obtained from the official package distribution. All **31,943 entries** were checked against that pinned CSV, with exact ordered equality of every `name` and `hex`. No subset or filtering was applied. Each JSON entry contains a nonempty string `name` and a six-digit `#RRGGBB` string `hex`.

The color-name-list license is **MIT**, copyright 2017 David Aerne. The exact original license is included as `assets/licenses/color-name-list-LICENSE.txt`, downloaded from [LICENSE at the release source commit](https://raw.githubusercontent.com/meodai/color-names/61eacc60cf6c5491aa423b3d7186c70e6a25b2b8/LICENSE). Preserve the bundled copyright and license when redistributing the data.

The downloaded npm archive was verified against its registry SHA-512 integrity:

```text
sha512-01z5RE6cwr4dNNsv4/9602Z8QoMfVG0ncjss3cUnTAVoyFyjjpbqshH483myyapGtYxmD4ZUTCLnHAe2x0uXNQ==
```

## Verification and SHA-256 checksums

Both fonts passed the TrueType `0x00010000` signature check and contain an `fvar` table with the weight ranges documented above. The complete JSON parsed successfully and every row passed schema validation and comparison with the source CSV.

```text
09e8c114d57f63cde82dad08a0aaf2c5d88c9234aa4f6dc171f54b5b7d9b4b8a  assets/data/color_names.json
48715a42ec242c21e9f02692891e147d022299a52e48d5e413e1a942193ffeda  assets/fonts/JetBrainsMono-Variable.ttf
89b3fb38aa0d275d7a731d0d817a4f1622b316b4d7fbdedcf02ee9099ff68bc8  assets/fonts/PlusJakartaSans-Variable.ttf
b2fe5e8987594e9ffd1d2ca52a2f5d73eb8335243893c5d6254b5ad69269591d  assets/licenses/JetBrainsMono-OFL.txt
995c7199cab65954f545996326755daee7b63cc6b42b06c13da1f9502ab08a99  assets/licenses/PlusJakartaSans-OFL.txt
c5bc9b96e07b83b190604b21d0e03f2f95c551986ffd05ab3c613a23d5b0c5a5  assets/licenses/color-name-list-LICENSE.txt
```

## Room model feasibility evidence

The files in `docs/superpowers/evidence/room-model-spike/` are historical diagnostic
documentation, not runtime app assets. The later implemented Room editor and
production model bundle are documented separately below; no native host binary
is bundled in the source delivery.

`reference-room.jpg` is the unchanged 1280×853 Wikimedia derivative of Daderot's
photograph, taken 13 March 2017. Its [source page, fixed revision 1176476079](https://commons.wikimedia.org/w/index.php?title=File:Living_Room_-_Vizcaya_Museum_and_Gardens_-_Miami,_Florida_-_DSC08325.jpg&oldid=1176476079)
explicitly dedicates it under [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/).
SHA-256: `0960579a54bd33a54bd9f310b41028bdbf9e6c83e50e27a5555f6461902275b1`.
The INT8/UINT8 overlay PNGs and JSON diagnostics were generated locally from real
model invocations; they contain visible segmentation errors, not corrected paint.

The [model feasibility report](superpowers/plans/room-model-reselection-report.md)
records pinned model/source/recipe links, checksums, the literal MLCommons
Association License source and remaining provenance/runtime limits. Exact
upstream notices and the production model asset were subsequently retained in
Task 1; the historical spike alone was not the completed model-license bundle.

## Downloaded Room models and independent test fixture

Color Lab uses the unmodified MOSAIC R4 UINT8 model from
[`mlcommons/mobile_open` revision `404e4c284d01b1c9e415b09d7cf8aa0648c4015d`](https://github.com/mlcommons/mobile_open/tree/404e4c284d01b1c9e415b09d7cf8aa0648c4015d).
The [exact model](https://raw.githubusercontent.com/mlcommons/mobile_open/404e4c284d01b1c9e415b09d7cf8aa0648c4015d/vision/mosaic/models_and_checkpoints/R4/mobile_segmenter_r4_quant_argmax_uint8.tflite)
is renamed `room_seg.tflite`, with no byte changes, 1,978,000 bytes. The local
development copy may live at `assets/models/room_seg.tflite`, but is not bundled.
The complete literal [MLCommons Association License](https://raw.githubusercontent.com/mlcommons/mobile_open/404e4c284d01b1c9e415b09d7cf8aa0648c4015d/vision/mosaic/LICENCE.md)
is retained in `assets/licenses/room-model-LICENSE.txt`. Its copyright notice is
Copyright 2020 MLCommons Association. `room-model-NOTICE.txt` records provenance
and the filename-only change; no separate upstream NOTICE was found in the
inspected source tree. Both license files are registered in the app license list.

The second model is the unmodified [MiDaS v2.1 mobile model](https://github.com/isl-org/MiDaS/releases/download/v2_1/model_opt.tflite),
renamed `room_depth.tflite`: 66,338,288 bytes, SHA-256
`93d871071edff1218973ce25ee27ce95ccd20450c70a55e1b89efa3f5a772cdd`.
Its [MIT license](https://github.com/isl-org/MiDaS/blob/v2_1/LICENSE), copyright
2019 Intel ISL, and provenance are retained in `room-depth-LICENSE.txt` and
`room-depth-NOTICE.txt`, registered in the app's license list. The depth runner
uses whole-photo bilinear resizing to 256×256 and `(channel - 115) / 58`, following
the upstream mobile normalization but deliberately not its center crop. Relative
inverse depth protects Wall ownership against nearer foreground objects; it is
not an object detector or a metric distance measurement.

Both unchanged model binaries and all four license/notice files are distributed
in the fixed [Color Lab room-models-v1 Release](https://github.com/rowjoy/color_lab/releases/tag/room-models-v1).
Only the small descriptor and licenses are bundled. App startup checks saved files
and streams missing or corrupt public HTTPS assets into app-private support storage, verifies exact size
and pinned SHA-256, then promotes complete files. Cached files are verified before
reuse and support offline analysis. Partial, oversized, corrupt and failed
downloads are not promoted; retries preserve already verified peer models. The
app contains no GitHub credential and never uploads room photos.

`test/fixtures/room/reference_room.png` is a lossless PNG of the retained Daderot
CC0 JPEG's decoded/oriented RGB using Dart `image 4.12.0`. The PNG and decoded JPEG
have identical RGB bytes. Attribution is also retained beside the fixture in
`reference_room.LICENSE.txt`. The independent pre-Task-2 comparison input is
preserved verbatim as `reference_input.bin`: raw RGB 512×512, top-left floor-sized
512×341 content, aligned-corner bilinear, double arithmetic/channel truncation,
bottom padding RGB123/115/103. There is no JPEG re-encode and no external
normalization or requantization. This is not bit-exact TensorFlow benchmark
preprocessing. `model_reference.json` records boundary pixels and independently
observed MOSAIC class IDs, including the visible person misclassified as chair.
These test fixtures are not runtime app assets. The Unsplash-review-pending
comparison photo is not bundled.

```text
da8b3822a22fde45ecaf0ff32022287eff58b500096971b04f3c1b292da66a3c  assets/models/room_seg.tflite
1ed90e04b526a11df0cc002e19033c70b59e28520d2b266447517f7ddf0f9bcd  assets/licenses/room-model-LICENSE.txt
94023747b626de08cf3daf14695dfe5810efac833cae74f34792a9ac4005bad1  test/fixtures/room/reference_room.png
b1853a64f7bf077e61e208f7c2756c21f8cf4f55f520bc0c59d0ffd668b7415a  test/fixtures/room/reference_input.bin
b017ad00a827778f9e194f8a8a08787c71aaafc9f1913ad95e77a1bec132d113  decoded original/PNG RGB bytes
```

The [production validation report](superpowers/plans/room-model-production-validation-report.md)
records actual public-API production-runner invocation and host/mobile limits.

## Recorded Room mask preview fixture

`test/fixtures/room/reference_masks.bin` is the **verbatim actual Task5 default
production-service output**, 1,091,840 one-byte exclusive labels at 1280×853.
It is not a hand-painted mask or dense ground truth. Labels are 0 unselected,
1 Wall, 2 Ceiling, 3 Floor, 4 Furniture. Counts are respectively 206720,531957,
88231,46027,218905. `reference_masks.json` retains the original evidence fields,
host runtime2.11.0, preprocessing/inverse recipe, timing/heartbeat diagnostics,
model/descriptor/input/photo checksums and CC0 photo attribution, replacing the
temporary absolute mask path with a project-relative asset identity. Elapsed
262.686ms is one host service diagnostic, not phone latency or an accuracy score.

The source photo remains Daderot's CC0 Vizcaya image, with its original attribution
in `reference_room.LICENSE.txt` and fixed Commons revision linked above. These
locally derived ownership bytes and PNG previews visibly include native-model
errors: a person mislabeled chair/Furniture, ornate surfaces and sofa/pillow
misses. Manual refinement remains necessary. The small comparison sample has no
dense ground truth; no global-best or accuracy-percentage claim is made.

The preview renderer prepares the real bundled fixture photo, feeds these
recorded bytes only through the segmentation-service boundary and uses the real
Room controller, refinement worker and viewport. It performs no native inference
and demonstrates mask visualization, not paint recoloring. Actual inference
evidence belongs to the [Task5 report](superpowers/plans/room-task-5-report.md).

```text
5ab660689348ba538d622d681742d365d50ce8f08ee8bb3a8712bfa733c840ba  test/fixtures/room/reference_masks.bin
cf1bb10c7518cb4ff5e5403f856f1342280dbce8341a72c26fbd06d2e345d533  assets/models/room_seg_descriptor.json
```

## Repository-authored illustrated rooms and palettes

The six bundled room illustrations are repository-authored vector artwork. The
approved 2026-10-25 designs describe original scenes and prohibit tracing or
shipping the supplied reference images. The generated Study raster was used
only as non-shipping visual direction. Plan 05 derives strict region JSON and
fixed-decoration SVGs from these existing vectors; it introduces no downloaded
room imagery.

Git history records the prior artwork-polish commits below. The inspected
commits are attributed to repository contributor `rowjoy`; commit authorship is
not independent proof of copyright ownership and does not establish a separate
third-party license grant. No repository-wide LICENSE or room-artwork
LICENSE/NOTICE was found. The starter-palette NOTICE grants rights only to the
original palette values, names and descriptions; it does **not** grant rights to
the SVG or region JSON artwork.

| Template | Historical artwork commit | Final SVG SHA-256 | Final region JSON SHA-256 |
| --- | --- | --- | --- |
| Living | `c3116f5` | `17b9b89abf503af23faf2d18fc84bf94665df24a15289c570ed32c317a228b86` | `577ea777d36e5a8378aa9181cdac7bbde575f0ca0537340eb8bc614e7a3feafe` |
| Bedroom | `1f5a019` | `51239f270468bcb7b84393ef432c2b3c8eda076aee456c215cfd6770e47a7bdd` | `8d97f12556aade078b89fd5b29123c7ce01c8752299b83ba5d945ce4c39704ae` |
| Study | `6860456` | `d547a004155670db40e058afe1a4fb0a06c0d83e0376189ca210f45655e6ee0a` | `4b753ef541f8ee2a3011f80e7ad6bb499f96c17c248100d04e94733f7c8c1185` |
| Dining | `da27b9e` | `bc3464d1fbf701104ead3a3de053b7ad565bd6d871b2a5672fdb50b32c177e39` | `b0ac3e9d192b65ec26a93fa676e1cbf731e453e4b27c47d8fcefc28b10cd47eb` |
| Kitchen | `74c2a7e` | `d08f2a4a444c8d7fadf7e7ca97f695155c46373611a525dbb4fbc0c29336af93` | `c7390a425eb5a84a8f933745586b20eb77bdd1e0cf8bcc0f7622d05dd3a5340a` |
| Bathroom | `7e56c46` | `61c12bdca53ffc595b2396991c5468865eeee4461764892ae570e811b7e3add6` | `3d0edf621aa7aac0da31a2e001d525d0191a3ddc089e1dfc32ce6687424715fa` |

The design sources are
`docs/superpowers/specs/2026-10-25-svg-room-color-studio-design.md` and
`docs/superpowers/specs/2026-10-25-polished-3d-illustrated-rooms-design.md`.
Exact pre-region SVGs are retained as test-only migration fixtures rather than
runtime assets. Their raw-byte SHA-256 values are:

```text
81a400211f87253eeb844fc9f427f164091734077c60e8d01cb8aae6d13796e6  test/fixtures/illustrated_rooms/living_room_pre_regions.svg
d5f69379b8bba90a2e28fc7df0d982711a82a02701ed7fd9b564ac23a27818f4  test/fixtures/illustrated_rooms/bedroom_room_pre_regions.svg
3637e4f694387cb1ec2b5c2555f7cb969290ed5b9ef836fa69ce7cf8b58a8168  test/fixtures/study_room_pre_region_pilot.svg
dd13522ce28cdec7eaf9a601a15eaa39c661a114a18783ae3f8bafa6c531536a  test/fixtures/illustrated_rooms/dining_room_pre_regions.svg
876c7a4e136b2354a54c66d148ac28c845e5cab6506f4ae021ac219af0dc4d88  test/fixtures/illustrated_rooms/kitchen_room_pre_regions.svg
a5400b6a4e50bd9f4c4a1d058e51b189d75371564e20f1e4d60af258ed26c068  test/fixtures/illustrated_rooms/bathroom_room_pre_regions.svg
c34d867347480f5916a6bf79a69c5b7b5a5840c3b19cb752ca6f051e15714a8f  test/fixtures/illustrated_rooms/v1.json
```

The original, brand-neutral starter-palette catalogue is 1,722 bytes, SHA-256
`985ee30d37ea07270c50a35144fdc7669a2dba61e70783fa96d989a7875edf1c`.
Its 843-byte NOTICE is SHA-256
`e1bf7191aaf19a20ef9507636ba067033e950374e74fab9d558a8f75f048b8ba`.
Both are bundled. Runtime registration of that NOTICE in the protected
`lib/main.dart` license list remains a release prerequisite.

