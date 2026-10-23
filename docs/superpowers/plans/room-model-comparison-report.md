# Task 0: actual MOSAIC versus DeepLab room-photo comparison

Date: 2026-10-22. Scope: bounded feasibility comparison, not production-runner acceptance. No app source, dependencies, bundled assets, platform configuration, SDK, or prior evidence was changed by this comparison. No native compilation, APK, installation, clean, or application-data clearing was performed.

## Decision

Recommend **MOSAIC R4 UINT8** as the best balanced **tested usable candidate** for the next production gate. It loads and invokes through the unmodified public `tflite_flutter 0.12.1` API, has the required directly mapped room classes, occupies 1,978,000 bytes, and shows less wall/furniture spill over bedroom blinds than DeepLab. Its one-thread host invokes were faster than both alternatives. This is a tradeoff recommendation, not a claim of universal segmentation superiority: the brown-room cabinet and bedroom pillows regress, and all three candidates misclassify a visible person. Manual editing remains essential.

MOSAIC FP32 did not provide a consistent enough visible improvement to justify its larger 7,510,540-byte file. DeepLab UINT8 remains a compatible fallback with better cabinet coverage in the brown room. The tested photo sample is small and has no dense ground truth; no accuracy percentage or global-best claim follows from it. Target-phone latency, memory use, delegate behavior, Android 24/iOS 13 integration, and production preprocessing remain separate gates.

## Exact candidates and source chain

Both MOSAIC files are ADE20K R4, **not Cityscapes**, from `mlcommons/mobile_open` revision `404e4c284d01b1c9e415b09d7cf8aa0648c4015d`:

| Candidate | Bytes | SHA-256 |
|---|---:|---|
| MOSAIC R4 UINT8 | 1,978,000 | `da8b3822a22fde45ecaf0ff32022287eff58b500096971b04f3c1b292da66a3c` |
| MOSAIC R4 FP32 | 7,510,540 | `dc49c91960363a7f42bc3ecb4b473abfcdaaf9b122e7e585d8c8f90816e0871d` |
| DeepLab UINT8 baseline | 2,348,952 | `2d58c681d81b5e181816b81cc815b82edf3daad905b4d7d35afade80aee93b5f` |

Immutable downloads:

- [Selected MOSAIC UINT8](https://raw.githubusercontent.com/mlcommons/mobile_open/404e4c284d01b1c9e415b09d7cf8aa0648c4015d/vision/mosaic/models_and_checkpoints/R4/mobile_segmenter_r4_quant_argmax_uint8.tflite).
- [Compared MOSAIC FP32](https://raw.githubusercontent.com/mlcommons/mobile_open/404e4c284d01b1c9e415b09d7cf8aa0648c4015d/vision/mosaic/models_and_checkpoints/R4/mobile_segmenter_r4_argmax_f32.tflite).
- [DeepLab baseline](https://raw.githubusercontent.com/mlcommons/mobile_models/9c7b31ce63ff0331bd659ac2609c4e68b6b4ec0f/v0_7/tflite/deeplabv3_mnv2_ade20k_uint8.tflite).

The [official current Android backend settings](https://raw.githubusercontent.com/mlcommons/mobile_app_open/846c58df1233e3e602d9a138c3c7b4b7b21f9381/mobile_back_tflite/cpp/backend_tflite/backend_settings/tflite_settings_android.pbtxt) identify these R4 filenames for segmentation. Downloaded MD5 values match those settings exactly: UINT8 `b7a7620b8b818d64305b51ab796bfb1d`; FP32 `b3a5d3c2e5756431a471ed5211c344a9`. Only these two MOSAIC artifacts were downloaded; no training or conversion was attempted.

The [MLCommons benchmark page](https://mlcommons.org/benchmarks/inference-mobile/) lists MOSAIC ADE20K 32-class 512×512 FP32 mIoU 59.8 versus DeepLab 54.8. The [MOSAIC README](https://raw.githubusercontent.com/mlcommons/mobile_open/404e4c284d01b1c9e415b09d7cf8aa0648c4015d/vision/mosaic/README.md) describes the same historical Top31 protocol and reports 60.10 for its experiment. These are source-reported benchmark results, not measurements produced here, and the two MOSAIC figures are not interchangeable claims about this exact downloaded UINT8 file.

## Literal selected-model contract for Task 1/2

Selected local binary: `/private/tmp/color-lab-mosaic.MHAOp6/mosaic-r4-uint8.tflite`.

- FlatBuffer identifier `TFL3`, schema version 3, one subgraph, description `MLIR Converted.`.
- One input: tensor index 0, name `PreprocessedImageTensor`, **UINT8**, shape **[1,512,512,3]**, RGB NHWC, scale **0.007843137718737125**, zero point **128**.
- One output: tensor index 242, name `SemanticPredictions`, **INT32**, shape **[1,512,512]**, unquantized direct class IDs **0..31**. It is already argmax, not probabilities; do not argmax again or confidence-threshold the IDs.
- Final logits tensor index 241, shape `[1,512,512,32]`, UINT8, scale `0.0962192565202713`, zero point 0. Final built-in `ARG_MAX` uses constant **axis 3**.
- Required built-in operator/version pairs: `CONV_2D/v1`, `DEPTHWISE_CONV_2D/v2`, `ADD/v1`, `AVERAGE_POOL_2D/v1`, `SPLIT/v1`, `CONCATENATION/v1`, `QUANTIZE/v1`, `RESIZE_BILINEAR/v1`, `ARG_MAX/v1`. No custom or Flex operators.
- Metadata includes `min_runtime_version`; the metadata name alone is not used as compatibility proof. Actual public native invocation on TFLite 2.11.0 is the compatibility evidence below.

FP32 has the same input shape/name but FLOAT32 input and no quantization. Output is INT32 `[1,512,512]`, tensor 238, same semantic name and 32-channel argmax. It uses the same operator list without `QUANTIZE`.

### Label mapping

The [current official task definition](https://raw.githubusercontent.com/mlcommons/mobile_app_open/846c58df1233e3e602d9a138c3c7b4b7b21f9381/flutter/assets/tasks.pbtxt) binds MOSAIC to ADE20K, `num_classes:31`, 512×512. The [official ADE evaluator](https://raw.githubusercontent.com/mlcommons/mobile_app_open/846c58df1233e3e602d9a138c3c7b4b7b21f9381/flutter/cpp/datasets/ade20k.cc) compares predicted IDs directly with annotation IDs 1 through 31; zero is excluded from scored classes. This establishes direct ADE IDs rather than a guessed compact remapping. Names come from the [original ADE label table](https://raw.githubusercontent.com/CSAILVision/sceneparsing/4ce20bd9115d415d545b26eaa0387a0740838ba5/objectInfo150.txt).

| Layer | IDs |
|---|---|
| Wall | 1 wall |
| Ceiling | 6 ceiling |
| Floor | 4 floor |
| Furniture | 8 bed, 11 cabinet, 16 table, 20 chair, 24 sofa |
| Unselected/unscored, eligible for ignored-only fill | 0 ignore; approved ignored-only 3×3 morphological closing may fill these pixels |
| Protected/unselected | Every other nonzero ID, including 9 window, 13 person, 15 door, 19 curtain, 23 painting, 25 shelf, 28 mirror, 29 rug, 31 armchair |

Full historical 32-entry contract: `0 ignore, 1 wall, 2 building, 3 sky, 4 floor, 5 tree, 6 ceiling, 7 road, 8 bed, 9 window, 10 grass, 11 cabinet, 12 sidewalk, 13 person, 14 earth, 15 door, 16 table, 17 mountain, 18 plant, 19 curtain, 20 chair, 21 car, 22 water, 23 painting, 24 sofa, 25 shelf, 26 house, 27 sea, 28 mirror, 29 rug, 30 field, 31 armchair`.

Armchair 31 stays excluded because the accepted Furniture union has five classes. A pixel predicted as chair 20 is selected even if the photographed object is actually a person or armchair; label protection cannot correct model misclassification.

### Preprocessing and inverse mapping

The [official ADE preparation script](https://raw.githubusercontent.com/mlcommons/mobile_app_open/846c58df1233e3e602d9a138c3c7b4b7b21f9381/datasets/util/ade20k/resize_512_ade20k.py) invokes [DeepLab preprocessing](https://raw.githubusercontent.com/tensorflow/models/db2fab9906b8fcfe44948e6a300ff4ecc25853f1/research/deeplab/input_preprocess.py) and its [resize helper](https://raw.githubusercontent.com/tensorflow/models/db2fab9906b8fcfe44948e6a300ff4ecc25853f1/research/deeplab/core/preprocess_utils.py). The frozen comparison recipe is:

1. Decode the original JPEG, bake EXIF orientation, retain RGB.
2. `s=512/max(W,H)`, `w=floor(W*s)`, `h=floor(H*s)`.
3. Resize using bilinear sampling with `align_corners=true`: source coordinate `x*(W-1)/(w-1)`, likewise y; truncate interpolated channels to UINT8. Handle a dimension of one without division by zero.
4. Place at upper left of 512×512. Pad only bottom/right with RGB **[123,115,103]** (integer representation of the DeepLab mean padding).
5. Selected UINT8 input receives those RGB bytes directly. **No external normalization or zero-point subtraction.** The [official runtime normalizer](https://raw.githubusercontent.com/tensorflow/tensorflow/v2.6.0/tensorflow/lite/tools/evaluation/stages/image_preprocessing_stage.h) leaves UINT8 unchanged; for the compared FP32 file it computes `(channel-127.5)/127.5`.
6. Read output INT32 IDs, remove bottom/right padding, then nearest-neighbor map the valid w×h labels back to the oriented original: source mask index `floor(y*h/H)*512+floor(x*w/W)`.

This harness uses Dart JPEG decoding and double-precision interpolation, then UINT8 truncation. The historical TensorFlow preparation uses its own decoder/float32 arithmetic and saves a quality-100 JPEG before evaluation. The harness deliberately avoids that extra lossy re-encode. Consequently this is a documented product-candidate recipe, **not bit-exact benchmark preprocessing equivalence**. No per-photo normalization/threshold tuning was performed. Production code must freeze and independently test its byte recipe.

## Actual public-runtime execution

All **12 model/photo combinations** completed: three candidates, four identical original photos per candidate. Each combination performed one initial invocation plus three timed invokes on the same input. Both harness kernel compilation and each staged tester process exited 0. All outputs were INT32 with 262,144 entries and values in 0..31; observed minima were 1 and maxima ranged 24..31. UINT8 inputs spanned 0..255 and FP32 inputs -1..1.

Public API used: `Interpreter.fromBuffer`, `InterpreterOptions()..threads=1`, `getInputTensor(0).data`, `invoke()`, `getOutputTensor(0).data`, `close()`. No private native API, model conversion, custom op resolver, or SDK patch.

Native host: arm64 macOS, copied prebuilt Flutter tester and the unmodified macOS dylib from the exact published [tflite_flutter 0.12.1 archive](https://pub.dev/api/archives/tflite_flutter-0.12.1.tar.gz). The prior verified archive SHA-256 is `0bba9040d8decda0960d7abf8eabf32243bf092bc7d0084e8e19681866b0bdbe`; extracted package remains `/private/tmp/color-lab-runtime-audit.DoaBJ5`. Native `tfl.version` reports **2.11.0**. This is distinct from mobile runtime dependency versions, including the package's iOS TensorFlowLiteSwift 2.12.0 declaration.

- Staged tester: `/private/tmp/color-lab-mosaic.MHAOp6/host/bin/flutter_tester`, SHA-256 `b93f4a00c2122761e4ae508d5aeb75d5a8a6df94d4fe6432701d16c38c4fd53a`.
- Staged native library: `/private/tmp/color-lab-mosaic.MHAOp6/host/resources/libtensorflowlite_c-mac.dylib`, SHA-256 `b800483ff1ac0911ae8634ed77a69ffd9b14e4c36a92e43e341d0f7d85fc99c0`.
- Harness: `/private/tmp/color-lab-mosaic.MHAOp6/compare.dart`, SHA-256 `e77d7a281e57fb0be1afab7b15f0d6a179e8fefa8e538b7c4ce2824318d8efbd`.

Host median milliseconds, three warm invokes, one thread; excludes decode/resize/PNG output:

| Photo | DeepLab UINT8 | MOSAIC FP32 | MOSAIC UINT8 |
|---|---:|---:|---:|
| Vizcaya | 103.614 | 81.184 | 63.887 |
| Bedroom | 102.949 | 81.408 | 61.899 |
| Brown living room | 102.423 | 82.470 | 61.768 |
| Blue living room, supplemental | 103.069 | 80.851 | 63.550 |

These are host diagnostic timings, **not phone FPS, mobile latency, memory benchmarks, or MLPerf submissions**. No compatible-runtime fallback was needed. Stock `flutter test` is not claimed to pass; the explicit staged tester satisfies the package's executable-relative native loader.

## Photo evidence and visible results

Three retained comparison photos:

- Vizcaya: existing `docs/superpowers/evidence/room-model-spike/reference-room.jpg`, 1280×853, Daderot CC0; [source](https://commons.wikimedia.org/wiki/File:Living_Room_-_Vizcaya_Museum_and_Gardens_-_Miami,_Florida_-_DSC08325.jpg). Valid resized region 512×341.
- Bedroom: `/private/tmp/room-fixtures.ddEgO0/bedroom-london.jpg`, 1280×960, Mx. Granger own work CC0; [permanent source](https://commons.wikimedia.org/w/index.php?title=File:Bedroom_in_a_serviced_apartment_in_London.jpg&oldid=819970092). Region 512×384.
- Brown living room: `/private/tmp/room-fixtures.ddEgO0/living-room-brown-sofa.jpg`, 1280×854, Shixart1985 own work CC BY 2.0; [permanent source](https://commons.wikimedia.org/w/index.php?title=File:Modern_living_room_with_stylish_furniture_and_a_view_of_the_outdoors_in_a_cozy_apartment_setting.jpg&oldid=1187542399). Region 512×341. Retention requires attribution.

Supplemental blue-couch image was also tested equally across all models, but its Commons/Unsplash provenance had a review-needed flag. It remains scratch-only and is not proposed for bundled fixture retention. Results are descriptive supplemental evidence only.

Visually inspected all twelve overlays:

- **Bedroom:** MOSAIC substantially reduces false wall/furniture islands in the blind area. Broad wall, ceiling, bed and carpet regions are plausible in all three. UINT8 MOSAIC loses parts of the pillows and labels a larger gap between pillows as wall; FP32 has a smaller pillow defect. All include some lamps/bedside objects in inappropriate layers.
- **Vizcaya:** all identify major ceiling/wall/table/sofa areas, but ornate surfaces are difficult. DeepLab covers more actual floor yet also marks parts of tables as floor. MOSAIC reduces some table-floor spill but misses parts of the foreground sofa/pillows. All leak furniture onto visible visitors; MOSAIC is not a reliable person-protection improvement.
- **Brown living room:** all keep most dark curtains and TV unselected and recognize the sofa. DeepLab captures more of the low TV cabinet. MOSAIC UINT8 incorrectly calls much of that cabinet wall; FP32 leaves much of it unselected. All fail parts of the coffee table; FP32 marks more of it as floor. UINT8 keeps more of the rug unselected than FP32.
- **Supplemental blue living room:** MOSAIC improves continuous cabinet coverage but spills wall over part of the right curtain; UINT8 also spills furniture onto radiator/TV areas. DeepLab has cabinet holes and a radiator furniture island. This does not establish a universal winner.

Coverage below is percent of the valid resized photo region, **not accuracy**. Order is Wall / Ceiling / Floor / Furniture:

| Photo | DeepLab UINT8 | MOSAIC FP32 | MOSAIC UINT8 |
|---|---|---|---|
| Vizcaya | 43.46 / 10.39 / 8.90 / 22.90 | 48.23 / 8.38 / 5.17 / 21.04 | 48.65 / 8.12 / 4.25 / 20.03 |
| Bedroom | 30.69 / 6.02 / 9.58 / 31.87 | 27.48 / 5.58 / 8.94 / 30.84 | 28.16 / 6.01 / 9.29 / 29.44 |
| Brown living | 32.16 / 8.66 / 8.26 / 22.97 | 30.78 / 8.41 / 13.13 / 16.42 | 36.15 / 8.40 / 7.86 / 15.75 |

The parent selected these sparse coordinates **before model execution and output inspection**. They are point sanity checks, not dense ground truth or an accuracy benchmark:

| Original-photo point | DeepLab | MOSAIC FP32 | MOSAIC UINT8 |
|---|---:|---:|---:|
| Bedroom wall (1100,200) | 1 | 1 | 1 |
| Bedroom ceiling (850,20) | 6 | 6 | 6 |
| Bedroom bedcover (850,650) | 8 | 8 | 8 |
| Bedroom carpet (150,850) | 4 | 4 | 4 |
| Bedroom window (180,500) | 9 | 9 | 9 |
| Bedroom blind (200,170) | 19 | 9 | 9 |
| Vizcaya ceiling (300,45) | 6 | 6 | 6 |
| Vizcaya sofa (900,800) | 24 | 24 | 24 |
| Vizcaya table (400,730) | 16 | 16 | 16 |
| Vizcaya person (150,600) | **20** | **20** | **20** |
| Vizcaya floor (30,780) | 4 | 4 | 4 |

Blind classes 19 and 9 are both unselected. The person point is selected as chair 20 in all three; do not describe class exclusion as guaranteed person protection.

## Reproducibility and artifacts

Scratch root `/private/tmp/color-lab-mosaic.MHAOp6/`. Results are in `results/{deeplab-uint8,mosaic-f32,mosaic-uint8}/{vizcaya,bedroom,living-brown,living}/`:

- `class-ids-int32le.bin`: raw, exact little-endian INT32 predicted IDs.
- `class-ids.png`: one-channel image containing actual 0..31 IDs, not a colorized label remap.
- `combined-mask.png`: selected layer colors at original dimensions; black is unselected.
- `overlay.png`: 50% layer-color overlay on original photo.
- `input.png`: exact resized/padded UINT8 RGB image before optional FP32 normalization.
- `report.json`: shapes, types, input/output ranges, all-512 and valid-photo histograms, counts, point checks, all three timings and median.

Overlay legend: wall `(235,45,190)`, ceiling `(255,210,25)`, floor `(20,210,240)`, furniture `(50,235,85)`. Aggregate reports: `results/report.json` contains the initial three photos; `results/report-living-brown.json` adds the clear-provenance replacement. No old scratch evidence was edited.

Compile scratch Dart to Flutter kernel with the existing `dartaotruntime` and `frontend_server_aot.dart.snapshot`, using `/private/tmp/color-lab-public-api.CQKdyz/.dart_tool/package_config.json` and the SDK's `common/flutter_patched_sdk/`. Run `host/bin/flutter_tester --disable-vm-service --icu-data-file-path=/Users/jamirulislam/Applications/flutter/bin/cache/artifacts/engine/darwin-x64/icudtl.dat --enable-software-rendering --non-interactive --packages=/private/tmp/color-lab-public-api.CQKdyz/.dart_tool/package_config.json /private/tmp/color-lab-mosaic.MHAOp6/compare.dill`. Optional `ONLY_FIXTURE=living-brown` repeats only the replacement photo. This compiles kernel bytecode, not native application code.

## Distribution source and remaining gate

The exact model directory includes [vision/mosaic/LICENCE.md](https://raw.githubusercontent.com/mlcommons/mobile_open/404e4c284d01b1c9e415b09d7cf8aa0648c4015d/vision/mosaic/LICENCE.md), locally `/private/tmp/color-lab-mosaic.MHAOp6/LICENSE-mosaic.md`. Its heading is **MLCOMMONS ASSOCIATION LICENSE** and it states it reproduces Apache License 2.0 terms. Its notice identifies **Copyright 2020 MLCommons Association**. Preserve the complete exact license/notice text with the distributed model, identify the immutable source and SHA, and identify changes if modifying the file. No separate `NOTICE` file appeared in the inspected repository tree. The model remains byte-for-byte unmodified. This reports the distributed license evidence, not a legal opinion or a reconstructed training-data provenance audit.

Task 1/2 should bundle only the chosen pinned UINT8 model and exact applicable notice, implement the literal contract above, retain all four auto layers and manual tools, and run a fresh gate through the **production** runner. This scratch comparison is sufficient to choose a candidate; it does not substitute for output-domain validation, deterministic preprocessing tests, graceful model failure/cancel behavior, renderer integration, mobile package resolution, or device verification. Android minimum 24 and iOS minimum 13 remain fixed.
