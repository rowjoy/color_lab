# Room model validation — blocked at artifact contract

Historical report: this records the original Task 1 attempt against its approved
151-class requirement. A later, separate feasibility spike did execute native
inference and established the compact model's room-label mapping; see
[room-model-reselection-report.md](room-model-reselection-report.md) and the
proposed contract amendment. It does not retroactively complete this attempt.

Task 1 has **not passed**. The exact pinned model has 32 channels feeding its final ArgMax, which contradicts the required 151-class contract. No production model, descriptor, runner, dependency, fixture, or platform configuration was retained. No native inference was executed and no AI output or alignment/quality claim is made.

## Artifact and reproducible inspection

- Source: [MLCommons model at the required revision](https://github.com/mlcommons/mobile_models/blob/9c7b31ce63ff0331bd659ac2609c4e68b6b4ec0f/v0_7/tflite/deeplabv3_mnv2_ade20k_int8.tflite).
- Revision: `9c7b31ce63ff0331bd659ac2609c4e68b6b4ec0f`.
- Actual downloaded size: `2937616` bytes.
- SHA-256: `3960571f5e2de1cec771a8f7a15b86f31b94cceccac8d993addbc1e29829de6a`.
- Flatbuffer identifier `TFL3`; model schema version `3`; description `MLIR Converted.`.
- Staged model, inspector, unmodified upstream schema, repository tree and README: `/private/tmp/color-lab-room-gate.8SIEoz/artifact-probe.ZpL6Fy/`.
- Inspector: `inspect_model.dart`, a read-only Dart FlatBuffer reader whose field indices follow [TensorFlow v2.14.0 schema.fbs](https://github.com/tensorflow/tensorflow/blob/v2.14.0/tensorflow/lite/schema/schema.fbs). It is a metadata probe, not an interpreter or production verification tool.
- Host: macOS arm64; Dart SDK `3.11.0 (stable) (Mon Feb 9 00:38:07 2026 -0800)`.

Reproduce from any directory (no pub packages or native libraries required):

```sh
/Users/jamirulislam/Applications/flutter/bin/cache/dart-sdk/bin/dart /private/tmp/color-lab-room-gate.8SIEoz/artifact-probe.ZpL6Fy/inspect_model.dart /private/tmp/color-lab-room-gate.8SIEoz/artifact-probe.ZpL6Fy/deeplabv3_mnv2_ade20k_int8.tflite
shasum -a 256 /private/tmp/color-lab-room-gate.8SIEoz/artifact-probe.ZpL6Fy/deeplabv3_mnv2_ade20k_int8.tflite
xxd -s 2313488 -l 4 /private/tmp/color-lab-room-gate.8SIEoz/artifact-probe.ZpL6Fy/deeplabv3_mnv2_ade20k_int8.tflite
```

All three commands exited `0`. Inspector success means the metadata was read; it does not mean Task 1 passed.

## Literal binary evidence

| Tensor index/name | Shape | Type | Quantization |
| --- | --- | --- | --- |
| `204`, `MobilenetV2/MobilenetV2/input` | `[1,512,512,3]` | `UINT8` (schema enum `3`) | scale `0.007843137718737125`, zero point `127` |
| `199`, `logits/semantic/BiasAdd;logits/semantic/Conv2D;logits/semantic/biases1` | `[1,128,128,32]` | `INT8` (enum `9`) | scale `0.17170841991901398`, zero point `69` |
| `200`, `ResizeBilinear_1` | `[1,512,512,32]` | `INT8` (enum `9`) | scale `0.17170841991901398`, zero point `69` |
| `4`, `decoder/concat/axis` | `[]` (scalar) | `INT32` (enum `2`) | empty |
| `201`, `ArgMax` | `[1,512,512]` | `INT32` (enum `2`) | empty |

The final operator uses opcode index `6`, whose builtin code is `56` (`ARG_MAX`), version `2`. Its inputs are `[200,4]` and its output is `[201]`. Tensor `4` references buffer `5`, containing a four-byte INT32 value `3` at byte offset `2313488`. Independent raw-byte display:

```text
00234d10: 0300 0000                                ....
```

Therefore ArgMax selects axis `3` of `[1,512,512,32]`: its possible output indices are `0..31`. The required 151-class output cannot be supplied by this artifact. No invented offset, relabeling, padded label table, or alternate model was introduced.

The controller arranged an independent read-only review using a separate Ruby FlatBuffer decoder. That review corroborated the sole output tensor `201`, final builtin `ARG_MAX` code `56`, axis `3`, and 32-channel input. It independently recomputed the SHA-256 and Git blob SHA-1 `4b510dd88790e3037b51ef26b27aa3f4daf2004e`, matching the pinned repository-tree entry. The graph supports at most 32 output IDs; their semantic names and ignored-label meaning remain unverified.

The graph's operator codes/versions are `CONV_2D v3`, `DEPTHWISE_CONV_2D v3`, `ADD v2`, `AVERAGE_POOL_2D v2`, `RESIZE_BILINEAR v2`, `CONCATENATION v2`, `ARG_MAX v2`, and `QUANTIZE v2`. The metadata names vector contains only `min_runtime_version`; there is no embedded semantic label map. Ignored-label semantics were **not verified**. The pinned [TFLite README](https://github.com/mlcommons/mobile_models/blob/9c7b31ce63ff0331bd659ac2609c4e68b6b4ec0f/v0_7/tflite/README.md) describes conversion for the float model with input `1,513,513,3`; it supplies no class mapping or preprocessing recipe for this exact integer artifact. That float-model recipe was not substituted for actual binary facts.

Channel normalization, fixture selection/licensing, independent reference input, model license/notice packaging, semantic surface mapping and numeric room expectations remain unfinished because the explicit metadata stop condition was reached first.

## Runtime evidence and limits

The controller's separate static release audit inspected the exact published `tflite_flutter 0.12.1` archive, SHA-256 `0bba9040d8decda0960d7abf8eabf32243bf092bc7d0084e8e19681866b0bdbe`, staged at `/private/tmp/color-lab-runtime-audit.DoaBJ5/`. Its evidence reports Android plugin min SDK `19`, compile SDK `36`, AGP `8.6.1`, and LiteRT/LiteRT GPU `1.4.0` AAR manifests declaring minimum SDK `21`. Its iOS plugin and TensorFlowLiteSwift/TensorFlowLiteC `2.12.0` podspecs declare iOS `11.0`. The app's Android `24` and iOS `13` clear those inspected declared floors; this is not a native-device compatibility result. The release README's Android API `26` statement conflicts with the inspected manifests and is not by itself proof of incompatibility.

I directly inspected the release loader: macOS opens `${Directory(Platform.resolvedExecutable).parent.parent.path}/resources/libtensorflowlite_c-mac.dylib`. It exposes no assumed environment override. The static audit found an included universal arm64/x86_64 host library in `macos/libtensorflowlite_c-mac.dylib`, with macOS minimum `13.0`. This is only a candidate; loading, allocation and invocation were **not attempted** after the model contract failed. No SDK/pub-cache patch, private binding call or native compilation was used.

There is **no passing real inference, no mocked inference counted as evidence, no successful production runner smoke test, no room output, and no manual alignment review**. The hard gate remains closed; Tasks 2–10 must not start on this evidence.
