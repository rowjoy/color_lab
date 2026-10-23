# Room model feasibility findings

Date: 2026-10-22. Recommendation: use the pinned MLCommons **UINT8** sibling
under a corrected 32-output contract, subject to approval of the
[contract amendment](../specs/2026-10-22-room-model-contract-amendment.md).
Its public-API host invocation and room-photo output were reproduced by the main
agent. This is a completed feasibility spike, not product implementation or a
passing production runner/service gate.

## Correction to the previous assumption

The build document requires Wall, Ceiling, Floor and Furniture, not 151 output
classes. The previous plan introduced the 151-class requirement from a generic
TensorFlow ADE20K configuration. That assumption was wrong for these MLCommons
benchmark models. Stopping the original implementation prevented inventing IDs;
official historical benchmark sources now establish the compact model's mapping.

The [configuration at the pinned model revision](https://raw.githubusercontent.com/mlcommons/mobile_models/9c7b31ce63ff0331bd659ac2609c4e68b6b4ec0f/v1_0/assets/tasks_v2.pbtxt)
defines the DeepLab UINT8 variant with 31 scored classes and 512×512 dimensions.
The [historical settings](https://raw.githubusercontent.com/mlcommons/mobile_app_open/b957f961907dc3dda5e5e9d7bb183b5913ee5677/mobile_back_tflite/cpp/backend_tflite/tflite_settings.h)
link that variant to `v0_7/tflite/deeplabv3_mnv2_ade20k_uint8.tflite`.
The [evaluator](https://raw.githubusercontent.com/mlcommons/mobile_app_open/b957f961907dc3dda5e5e9d7bb183b5913ee5677/android/cpp/datasets/ade20k.cc)
compares output IDs directly with ADE20K annotation IDs 1–31; zero and higher
annotation IDs are unscored. The binary has 32 channels including slot zero.

Using the [original ADE20K author's label table](https://raw.githubusercontent.com/CSAILVision/sceneparsing/4ce20bd9115d415d545b26eaa0387a0740838ba5/objectInfo150.txt):

| Application selection | Original output IDs |
| --- | --- |
| Wall | 1 |
| Ceiling | 6 |
| Floor | 4 |
| Furniture | 8 bed, 11 cabinet, 16 table, 20 chair, 24 sofa |
| Protected examples, not selected | 9 windowpane, 15 door, 31 armchair |
| Excluded slot | 0, unscored; not a reliable detector of every omitted class |

No permutation or zero-based SegFormer offset is applied. Other nonzero classes
remain unselected and protected from ignored-pixel filling.

## Candidate comparison

| Candidate | Actual or published evidence | Decision |
| --- | --- | --- |
| Original MLCommons INT8-named file | Locally inspected 2,937,616 bytes, UINT8 input, 32 output channels; actual host room invocation succeeded. | Historical attempt remains rejected against its original 151-class contract. UINT8 sibling has a clearer exact-filename settings link. |
| MLCommons FLOAT32 sibling | Locally inspected 9,076,480 bytes; SHA-256 `12a2141f28928a9bccce5063d0f868211c9d2633a263b9141594ff300daeafc0`; also 32 channels, not 151. | Not a 151-class replacement; not the selected quantized artifact. |
| MLCommons UINT8 sibling | Locally inspected and actually invoked; exact details below. | Recommended compact quantized candidate for the revised contract. |
| [Qualcomm SegFormer](https://huggingface.co/qualcomm/Segformer-Base/tree/dfccf620614b59c8aa1894b5e8ad0cf93f863a2f) | Publisher describes 150 classes and proprietary compiled-asset terms; original NVIDIA model lineage. Binary not downloaded or inspected. | Not accepted as a permissive drop-in replacement. |
| [PINTO 026](https://github.com/PINTO0309/PINTO_model_zoo/tree/9a409ba14c21891ba3b0072a827368e508438926/026_mobile-deeplabv3-plus) | Provenance points to [VOC/people segmentation](https://github.com/nolanliou/mobile-deeplab-v3-plus), not the required room classes. Binary not inspected. | Not suitable. |
| [TIPSv2](https://huggingface.co/litert-community/TIPSv2-B14-DPT-LiteRT/tree/8231829b1273ca39ce731a92cbad8b28941fef78) | Publisher documents 150 classes, Apache-2.0 upstream and a 318,337,760-byte asset; no local binary or exact-runtime verification. | Not recommended for the existing compact mobile target. Published metadata is not a measured local artifact. |

The selected UINT8 asset is below the build document's 5–15 MB size target, as the
previous INT8 candidate also was. This size exception must remain explicit.

## Inspected UINT8 artifact

- [Immutable model download](https://raw.githubusercontent.com/mlcommons/mobile_models/9c7b31ce63ff0331bd659ac2609c4e68b6b4ec0f/v0_7/tflite/deeplabv3_mnv2_ade20k_uint8.tflite).
- Revision: `9c7b31ce63ff0331bd659ac2609c4e68b6b4ec0f`.
- Size: **2,348,952 bytes**.
- SHA-256: `2d58c681d81b5e181816b81cc815b82edf3daad905b4d7d35afade80aee93b5f`.
- Pinned Git blob: `982adb41100ec2df195cc51c53cb5ab93dc94a71`.
- Input tensor 6: UINT8 `[1,512,512,3]`, scale `0.0078125`, zero point `128`.
- Output tensor 0: INT32 `[1,512,512]`.
- Final logits tensor 199: `[1,128,128,32]`; resized tensor 169:
  `[1,512,512,32]`; final ArgMax takes tensor 169 and constant axis tensor 1,
  whose value is 3. Output IDs must be in 0–31.
- Builtin versions: ADD 1, AVERAGE_POOL_2D 1, CONCATENATION 1, CONV_2D 1,
  DEPTHWISE_CONV_2D 1/2, RESIZE_BILINEAR 1, ARG_MAX 1. No custom operators.

The original INT8 inspector hardcoded axis tensor 4, so it must not be reused
unchanged for this differently ordered TOCO graph. The UINT8 inspector follows
the actual final operator to tensor 1. Main reproduced this inspection and hash.

## Input recipe and limits

The [historical dataset preparation](https://raw.githubusercontent.com/mlcommons/mobile_app_open/846c58df1233e3e602d9a138c3c7b4b7b21f9381/datasets/util/ade20k/resize_512_ade20k.py)
uses [DeepLab preprocessing](https://raw.githubusercontent.com/tensorflow/models/db2fab9906b8fcfe44948e6a300ff4ecc25853f1/research/deeplab/input_preprocess.py)
and its [resize helper](https://raw.githubusercontent.com/tensorflow/models/db2fab9906b8fcfe44948e6a300ff4ecc25853f1/research/deeplab/core/preprocess_utils.py):
aspect-preserving longest side 512, floored content dimensions, aligned-corner
bilinear interpolation and bottom/right padding. Padding becomes RGB
`[123,115,103]` after UINT8 conversion. An extreme narrow dimension must be
clamped to one pixel in the app and covered by independent tests.

The [runtime default normalization](https://raw.githubusercontent.com/tensorflow/tensorflow/v2.6.0/tensorflow/lite/tools/evaluation/stages/image_preprocessing_stage.h)
leaves actual UINT8 pixels unchanged: RGB 255 becomes byte 255. Do not normalize
then quantize again using the tensor scale. That scale/zero point describe the
native tensor and must still be validated against the descriptor.

The diagnostic probe used Dart double interpolation and `image 4.12.0` decoding,
and omitted the historical JPEG quality-100 re-encode. It is **not bit-exact
TensorFlow preprocessing evidence**. The proposed product path also avoids a
lossy JPEG re-encode, explicitly freezes its deterministic byte recipe, and still
needs independent numeric/reference tests before Task 1/2 acceptance.

## Actual host execution

Exact published `tflite_flutter 0.12.1` archive SHA-256:
`0bba9040d8decda0960d7abf8eabf32243bf092bc7d0084e8e19681866b0bdbe`.
The unmodified package's macOS dylib reports TFLite **2.11.0**, distinct from the
mobile release dependency versions. A task-local copy of the prebuilt Flutter
tester is placed in `host/bin/` and that dylib in `host/resources/`, satisfying
the package's executable-relative public loader without SDK or package patches.

Both kernel compilation and actual public `Interpreter.fromBuffer`/`invoke`
exited 0. The main agent independently repeated the room-photo run: 110 ms for
that invocation, not a device latency promise. Its output counts matched the
implementer's separate run. The probe source is throwaway, not a production
`RoomModelRunner` or service.

Scratch: `/private/tmp/color-lab-public-api.CQKdyz/`. Dependencies were resolved
normally into its own `PUB_CACHE`. Source: `bin/photo_probe.dart`. Compilation:

```sh
/Users/jamirulislam/Applications/flutter/bin/cache/dart-sdk/bin/dartaotruntime \
  /Users/jamirulislam/Applications/flutter/bin/cache/artifacts/engine/darwin-x64/frontend_server_aot.dart.snapshot \
  --sdk-root /Users/jamirulislam/Applications/flutter/bin/cache/artifacts/engine/common/flutter_patched_sdk/ \
  --target=flutter --no-print-incremental-dependencies --no-link-platform \
  --packages /private/tmp/color-lab-public-api.CQKdyz/.dart_tool/package_config.json \
  --output-dill /private/tmp/color-lab-public-api.CQKdyz/photo-probe-uint8.dill \
  --verbosity=error /private/tmp/color-lab-public-api.CQKdyz/bin/photo_probe.dart
```

Execution:

```sh
ROOM_PROBE_MODEL=/private/tmp/color-lab-float.j8BkYD/deeplabv3_mnv2_ade20k_uint8.tflite \
ROOM_PROBE_OUTPUT=/private/tmp/color-lab-public-api.CQKdyz/photo-output-uint8 \
/private/tmp/color-lab-public-api.CQKdyz/host/bin/flutter_tester \
  --disable-vm-service \
  --icu-data-file-path=/Users/jamirulislam/Applications/flutter/bin/cache/artifacts/engine/darwin-x64/icudtl.dat \
  --enable-software-rendering --non-interactive \
  --packages=/private/tmp/color-lab-public-api.CQKdyz/.dart_tool/package_config.json \
  /private/tmp/color-lab-public-api.CQKdyz/photo-probe-uint8.dill
```

This compiles Flutter kernel bytecode, **not a native app or APK**. No native
compiler, installation, SDK/pub-cache patch or private TensorFlow API was used.
The copied tester SHA-256 is
`b93f4a00c2122761e4ae508d5aeb75d5a8a6df94d4fe6432701d16c38c4fd53a`;
the exact archive dylib SHA-256 is
`b800483ff1ac0911ae8634ed77a69ffd9b14e4c36a92e43e341d0f7d85fc99c0`.

The stock `flutter test tool/verify_room_model.dart --no-pub --reporter expanded`
has **not passed**: its SDK tester lacks the expected resources dylib. There is
no direct tester-path flag; local-engine flags redirect more than that executable.
The plan must explicitly adopt a staged public-API smoke harness, which must
exercise the future production runner and, in Task 5, default worker factory.
Normal tests/analyzer/format remain separate gates. Asset loading in that future
production-service harness is not established by this file-input probe.

Android 24/iOS 13 declared floors remain unchanged. Static release metadata fits
those minima; physical-device loading, compatibility, latency and memory are not
verified by the host result.

## Room photo and visual evidence

[Original photo](../evidence/room-model-spike/reference-room.jpg) and
[UINT8 diagnostic overlay](../evidence/room-model-spike/uint8-mask-overlay.png).
Legend: magenta Wall, yellow Ceiling, cyan Floor, green Furniture. These are
model mask diagnostics, not recolored paint or an implemented app screen.

The source is Daderot's photograph, 13 March 2017, explicitly dedicated under CC0
on the [Commons page](https://commons.wikimedia.org/w/index.php?title=File:Living_Room_-_Vizcaya_Museum_and_Gardens_-_Miami,_Florida_-_DSC08325.jpg&oldid=1176476079).
The unchanged Wikimedia 1280×853 derivative is 351,678 bytes, SHA-256
`0960579a54bd33a54bd9f310b41028bdbf9e6c83e50e27a5555f6461902275b1`.
The model input content is 512×341 with 171 rows of bottom padding.

| Selection | Pixels in the unpadded 512×341 output region |
| --- | ---: |
| Wall | 75,879 |
| Ceiling | 18,138 |
| Floor | 15,543 |
| Furniture, exactly five specified classes | 39,982 |

Main visually inspected the original, combined and individual masks. Broad wall
and ceiling layout is plausible, but some people become furniture and sofa/table
boundaries become floor; wall spill is also visible. These errors are not fixed
by the probe. One image is not an accuracy benchmark, and these counts are not
confidence scores. Manual refinement remains necessary after AI succeeds.

The retained [numeric diagnostic](../evidence/room-model-spike/uint8-diagnostic.json)
contains the full histogram, mapping and limitations. The separate INT8 diagnostic
is preserved for comparison. Output raw IDs and masks were not hand-drawn.

```text
b1853a64f7bf077e61e208f7c2756c21f8cf4f55f520bc0c59d0ffd668b7415a  input RGB bytes
2906382b7850a636692e3e607c7534ab705ddc18ccdbf1bfd7786befb4c59dc1  uint8-mask-overlay.png
89435631a1c9a537ffa17347f62d03e89fd15a646f7bb379eb8bf3e0fbdd4a15  uint8-diagnostic.json
```

## Distribution notices and remaining gates

The exact model repository's [MLCommons Association License](https://raw.githubusercontent.com/mlcommons/mobile_models/9c7b31ce63ff0331bd659ac2609c4e68b6b4ec0f/LICENSE.md)
states that it reproduces Apache License 2.0 unchanged. Preserve its literal
upstream text and applicable notices when bundling; do not replace it with a
generic license filename's contents. Exact training-checkpoint/weight provenance
was not reconstructed, and this report does not claim comprehensive license
clearance or rights beyond the upstream grant.

Still required after amendment approval: Task 1 test-first descriptor/public
runner and negative checks, notice bundle, independently checked reference
tensor, reproducible staged production-runner smoke, then Task 2 processing and
Task 5 real default-service smoke. Only after those gates may manual tools begin.
No app code, dependency, native configuration or runtime model asset changed in
this spike; no APK/native build/install/clean/data clear was performed.

Fresh unchanged-app checks: `flutter test --no-pub --reporter expanded` exited 0
with 569 tests; `flutter analyze --no-pub` exited 0 with no issues;
`dart format --output=none --set-exit-if-changed lib test tool` exited 0,
146 files and 0 changes. Product/source snapshot comparisons and old APK/nine
ZIP hash checks were unchanged. These are regression checks, not completion of
the proposed Room implementation.

An independent read-only evidence review checked the retained hashes, source/
model/label linkage, public API probe and visual limitations: PASS, no material
factual corrections. It did not approve the amendment or validate production
integration, physical devices, general accuracy or comprehensive weight provenance.
