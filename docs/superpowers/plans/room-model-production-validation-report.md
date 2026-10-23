# Room model production validation

Date: 2026-10-22. Task 1 host gate: **PASS**. This is production-runner evidence,
not completion of the Room editor, inference worker, manual tools or device gate.
No native application compilation, APK, installation, clean or data clearing.

Scope correction: standard Dart/Flutter hooks did compile the preexisting
objective_c host support dependency during Task1. They did not compile the app
or TFLite library. Blanket no-native-compilation claims elsewhere are corrected
by [the guarded verification note](room-verification-guard.md); remaining smoke
uses direct dartvm and a tested native-compiler-deny profile.

## Artifact, native contract and provenance

Bundled `assets/models/room_seg.tflite` is the exact unmodified MOSAIC R4 UINT8
[artifact at revision 404e4c284d01b1c9e415b09d7cf8aa0648c4015d](https://raw.githubusercontent.com/mlcommons/mobile_open/404e4c284d01b1c9e415b09d7cf8aa0648c4015d/vision/mosaic/models_and_checkpoints/R4/mobile_segmenter_r4_quant_argmax_uint8.tflite).
Size 1,978,000 bytes; SHA-256
`da8b3822a22fde45ecaf0ff32022287eff58b500096971b04f3c1b292da66a3c`.
The original [MLCommons Association License](https://raw.githubusercontent.com/mlcommons/mobile_open/404e4c284d01b1c9e415b09d7cf8aa0648c4015d/vision/mosaic/LICENCE.md)
is preserved literally, checksum
`1ed90e04b526a11df0cc002e19033c70b59e28520d2b266447517f7ddf0f9bcd`.
The bundled notice identifies Copyright 2020 MLCommons Association, exact source,
checksum and filename-only change. No separate upstream NOTICE was found in the
inspected source tree. This records licensing evidence, not legal advice or a
training-data provenance audit.

Read-only FlatBuffer reinspection of the bundled artifact confirmed `TFL3`, schema
3, description `MLIR Converted.`, one graph and the following facts. Public native
tensor validation during the real production constructor confirmed the tensor
names, counts, types, shapes and byte sizes.

| Boundary | Actual value |
| --- | --- |
| Input tensor | index 0, `PreprocessedImageTensor`, UINT8 `[1,512,512,3]`, 786,432 bytes |
| Input quantization | scale `0.007843137718737125`, zero point 128 |
| Output tensor | index 242, `SemanticPredictions`, INT32 `[1,512,512]`, 1,048,576 native bytes |
| Output quantization | no scales/zero points; direct integer class IDs |
| Final logits | tensor 241, UINT8 `[1,512,512,32]` |
| Final ARG_MAX | input tensors `[241,2]`; scalar tensor 2 `ArgMax/dimension`, value 3 |
| Required operators | `CONV_2D:1`, `DEPTHWISE_CONV_2D:2`, `ADD:1`, `AVERAGE_POOL_2D:1`, `SPLIT:1`, `CONCATENATION:1`, `QUANTIZE:1`, `RESIZE_BILINEAR:1`, `ARG_MAX:1` |

The existing scratch schema inspector was used read-only for metadata. Its old
DeepLab-specific `argMaxAxisTensor` field hardcodes tensor 4 and is inapplicable
to MOSAIC; a fresh scratch inspection followed the final operator's actual inputs
and confirmed scalar tensor 2/value 3. No inspector code was promoted to production.

The descriptor freezes all 32 canonical labels from the approved amendment:
unscored 0, original ADE IDs 1–31, `windowpane` 9. Wall=1, Ceiling=6, Floor=4;
Furniture exactly 8/11/16/20/24. Door15, windowpane9, armchair31 and every other
nonzero class remain unselected in later mapping. Raw outputs still preserve all
IDs. Task 1 performs no morphological close or layer postprocessing.

Input encoding is **raw UINT8 RGB**. Identity channel metadata `[0,0,0]` /
`[1,1,1]` must not cause normalization, zero-point subtraction or requantization.
The runner transfers bytes through the public `Tensor.data` setter. Android
validates public `Tensor.params`; macOS uses the inspected schema bound to the
exact SHA because that public API is documented Android-only. No private binding
or ABI override is used.

## Published runtime and actual production invocation

Resolved exact `tflite_flutter 0.12.1`; archive/lock SHA-256
`0bba9040d8decda0960d7abf8eabf32243bf092bc7d0084e8e19681866b0bdbe`.
The release's unmodified macOS dylib SHA-256 is
`b800483ff1ac0911ae8634ed77a69ffd9b14e4c36a92e43e341d0f7d85fc99c0`.
Actual public `tfl.version` reports **2.11.0**, on macOS arm64, one CPU thread.
The published Android Gradle declaration uses LiteRT/litert-gpu 1.4.0 and plugin
minSDK19; the iOS podspec declares TensorFlowLiteSwift 2.12.0 (including Metal and
CoreML) and plugin iOS11. These declarations are not phone execution evidence.
App Android24 and iOS13 settings are unchanged, byte-compared with the baseline.
No additional app packaging line was required for this host gate.

From the project root:

```sh
/Users/jamirulislam/Applications/flutter/bin/cache/dart-sdk/bin/dart run tool/run_room_model_smoke.dart --flutter-root /Users/jamirulislam/Applications/flutter
```

Final run: exit **0**; staging
`/var/folders/vn/y_l64w1143dgf2j0sjxl8z8h0000gn/T/color-lab-room-smoke.SoCrkN`.
The wrapper uses the existing `dartaotruntime` and
`frontend_server_aot.dart.snapshot`, `--target=flutter`, the SDK's patched SDK and
project package config to compile **kernel bytecode only**. It copies the existing
tester and package dylib into fresh executable-relative `host/bin` /
`host/resources`; model/descriptor assets are staged under `flutter_assets`.
The verifier loads both via real Flutter `rootBundle`, then constructs and invokes
`TfliteRoomModelRunner`. No comparison probe or fake runner supplies output.
Copied host binaries remain outside delivery.

The tester uses `--run-forever` so async asset loading can finish; the verifier
explicitly exits. The wrapper imposes a 60-second timeout and requires a parsed
PASS/inference record even when the process exits zero. A silent zero exit is a
failure. It propagates nonzero child exits.

Actual first-invoke time in the final run was **71.488 ms** including runner
output validation/snapshot, not a target-phone latency claim. Actual output:

```json
{"elements":262144,"histogramAll512":[0,105441,28234,177,9434,12338,14180,197,0,5907,0,4135,119,2660,0,2740,38388,344,0,512,4877,0,0,14851,9290,12,0,0,1059,0,0,7249],"histogramPhotoRegion":[0,84942,0,0,7427,0,14180,0,0,5907,0,0,0,2660,0,2740,21535,0,0,512,4877,0,0,14851,8558,0,0,0,1059,0,0,5344],"layerPixels":{"wall":84942,"ceiling":14180,"floor":7427,"furniture":34970}}
```

All IDs were in 0–31 (observed min1/max31). The whole histogram exactly matches
the independently generated MOSAIC comparison reference. Sparse original-photo
points ceiling(300,45), sofa(900,800), table(400,730), person(150,600), floor(30,780)
produce IDs **6,24,16,20,4** at their frozen mapped coordinates. The person is
incorrectly classified as chair20 and would enter Furniture. This is a documented
model error, not evidence of reliable person protection or measured accuracy.

The executable also verifies rejected corrupt model bytes, input byte length,
output domain, four nonempty supported surfaces, independent anchors, detached
snapshot after a second invocation with different all-zero input, idempotent
close and rejection after close. Output IDs are range-checked as signed INT32
before conversion to the immutable Uint16 snapshot.

## Negative gates

Each command below uses the same Dart executable and `--flutter-root` above.

| Additional arguments | Actual exit/result |
| --- | --- |
| `--model /private/tmp/color-lab-task1.beKWbF/missing.tflite` | 1, required file missing |
| `--native-library /private/tmp/color-lab-task1.beKWbF/missing.dylib` | 1, required file missing |
| `--model assets/models/room_seg_descriptor.json` | 1 after actual kernel launch and asset load; production constructor throws `Room model SHA-256 mismatch`; wrapper propagates exit1 |

The focused unit gate additionally rejects malformed dimensions/lengths,
out-of-domain raw IDs, incompatible descriptor shapes/types/quantization/labels
and an output without supported surfaces. Those synthetic negative checks are
**not** counted as AI inference evidence. The smoke's corresponding validation
throws into its nonzero failure path; no skip/fallback marks AI successful.

## Independent fixture and numerical limits

Daderot's CC0 1280×853 Vizcaya derivative is the original retained JPEG, SHA-256
`0960579a54bd33a54bd9f310b41028bdbf9e6c83e50e27a5555f6461902275b1`.
See [fixed source page](https://commons.wikimedia.org/w/index.php?title=File:Living_Room_-_Vizcaya_Museum_and_Gardens_-_Miami,_Florida_-_DSC08325.jpg&oldid=1176476079)
and the fixture attribution. Dart `image 4.12.0` decoded/baked orientation and
losslessly encoded the result as PNG. RGB byte equality was checked across that
PNG round trip, hash `b017ad00a827778f9e194f8a8a08787c71aaafc9f1913ad95e77a1bec132d113`.
PNG SHA-256: `94023747b626de08cf3daf14695dfe5810efac833cae74f34792a9ac4005bad1`.

The preexisting independently generated reference input was copied verbatim,
**not regenerated from future production preprocessing**: 786,432 bytes, SHA-256
`b1853a64f7bf077e61e208f7c2756c21f8cf4f55f520bc0c59d0ffd668b7415a`.
Recipe: floor top-left aspect fit 512×341; bilinear aligned corners in double
precision; clamp/truncate to UINT8; pad bottom/right RGB123/115/103. No JPEG
re-encode. The historical TensorFlow benchmark uses its own decoder, float32
arithmetic and an additional JPEG encode; bit-exact benchmark equivalence is not
claimed. PNG retains the comparison decoder's exact RGB, so Task 2 can compare
its deterministic preprocessing against the frozen full input file.
The independently used channel expression is
`((a+(b-a)*dx)*(1-dy)+(c+(d-c)*dx)*dy).toInt().clamp(0,255)`, with a/b/c/d
top-left/top-right/bottom-left/bottom-right. Its double-arithmetic operation order
is recorded in the JSON reference to make full-byte comparison reproducible.

Hand-checked aligned-corner boundaries (these source coordinates require no
interpolation) and padding:

| Input x,y | Source x,y | Literal RGB |
| --- | --- | --- |
| 0,0 | 0,0 | 218,199,153 |
| 511,0 | 1279,0 | 98,57,13 |
| 0,340 | 0,852 | 189,220,226 |
| 511,340 | 1279,852 | 33,27,17 |
| 0,341 | padding | 123,115,103 |
| 511,511 | padding | 123,115,103 |

No source/PNG anchor differences occurred. Comparison raw INT32LE output hash
`ba08e82509cf6cc97ef9d150d649c1a045b7baf432e6c5a7eeb17364b5c66bb9`
is frozen in `model_reference.json`; raw comparison output was never supplied to
the production runner. Host output equality is not a cross-device bit-exact
guarantee.

Remaining separate gates: Task2 preprocessing/protected ignored-only closing,
Task5 default worker factory and worker asset lifecycle, UI/manual integration,
physical Android/iOS compatibility, device latency/memory/delegates. No class0
occurs in this real fixture, so it cannot prove ignored-only close behavior.
Visible ornate-surface, furniture, pillow, floor and person errors from comparison
remain; this small photo sample has no dense ground truth.
