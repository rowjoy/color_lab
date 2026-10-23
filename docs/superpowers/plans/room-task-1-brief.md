### Task 1: Verify and bundle the real model and runtime

**Files:**

- Create: `assets/models/room_seg.tflite`, `assets/models/room_seg_descriptor.json`, `assets/licenses/{room-model-LICENSE,room-model-NOTICE}.txt`; preserve the original license and record provenance/applicable notices.
- Create: `lib/features/room_studio/segmentation/{room_model_descriptor,raw_segmentation,room_model_runner}.dart`.
- Create: `tool/verify_room_model.dart`, `test/fixtures/room/{reference_room.png,reference_input.bin,model_reference.json,reference_room.LICENSE.txt}` and fixture attribution in `docs/asset-sources.md`.
- Test: `test/features/room_studio/segmentation/room_model_descriptor_test.dart`.
- Modify: `pubspec.yaml`, `pubspec.lock`, `lib/main.dart` license registration, `docs/asset-sources.md`; only required model-runtime packaging lines in `android/app/build.gradle.kts`/`ios/Podfile` if the verified release requires them.

**Interfaces:**

- `RoomTensorType { float32, int8, uint8, int32, int64 }`; immutable `RoomModelDescriptor.fromMap(Map<String,Object?>)`. Exact getters: `schemaVersion`=1, `sourceRevision`, `sha256`, `requiredOperators`, `inputShape`, `outputShape`, `inputType`, `outputType`, `channelMeans`, `channelStdDevs`, nullable `inputScale`/`inputZeroPoint`, `classCount`=151, `ignoredLabel`=0, `labelsById: Map<int,String>`, `inputWidth`, `inputHeight`, `outputWidth`, `outputHeight`, and `int idForName(String)` (FormatException if absent). Validate 64 hex checksum, finite three-channel normalization with positive stddevs, paired valid quantization for integer input, complete unique labels, batch-one RGB input and integer class-map output. Actual tensor dimensions/normalization are frozen from the binary, not guessed; this is not an arbitrary-model framework.
- `RawSegmentation({required int width, required int height, required Uint16List classIds})`: immutable snapshot, positive dimensions, exactly width×height entries.
- `abstract interface class RoomModelRunner { RoomModelDescriptor get descriptor; RawSegmentation invoke(Uint8List inputTensorBytes); void close(); }`.
- `TfliteRoomModelRunner(Uint8List modelBytes, RoomModelDescriptor descriptor)` validates native tensors against the descriptor before invocation. Task 5 constructs it inside its worker; no interpreter/native handle is sent from the UI isolate.

- [ ] **Write descriptor and actual-interpreter checks.** Invalid shape/type/quantization/labels/byte lengths must fail. The real verification tool must fail nonzero on a missing library, missing model, malformed output or absent supported surface; it must never skip or count a fake runner as AI evidence.

```dart
expect(() => RoomModelDescriptor.fromMap({'schema': 99}), throwsFormatException);
expect(() => RawSegmentation(width: 2, height: 2,
  classIds: Uint16List(3)), throwsArgumentError);
```

- [ ] **Observe RED.** Run `flutter test --no-pub test/features/room_studio/segmentation/room_model_descriptor_test.dart --reporter expanded`; the new owned API/asset is initially missing. Record exact exit/reason, not a fabricated behavioral failure.
- [ ] **Acquire and pin assets.** Download only the pinned [MLCommons binary](https://github.com/mlcommons/mobile_models/blob/9c7b31ce63ff0331bd659ac2609c4e68b6b4ec0f/v0_7/tflite/deeplabv3_mnv2_ade20k_int8.tflite), compute its checksum and preserve applicable licenses/notices. Select and attribute a redistribution-permitted room fixture with visible wall/floor areas.
- [ ] **Freeze the inspected descriptor and reference input.** Inspect the actual flatbuffer/native tensor contract and preprocessing source; freeze literal facts in JSON. Confirm expected 151 classes/ignored zero against the artifact; stop if it differs. Do not infer input dtype or normalization from its filename. Generate `reference_input.bin` with a separately verified upstream recipe, recording recipe/transform/checksum in `model_reference.json`. The first smoke tool invokes fixed bytes without depending on Task 2; Task 2 later checks its own preprocessing against independent reference pixels.
- [ ] **Pass the runtime compatibility probe.** Trial exact published [tflite_flutter 0.12.1](https://pub.dev/packages/tflite_flutter/versions/0.12.1) and inspect that release's native dependencies, not just moving `main`. Stage probes in a task-specific temporary directory before retaining app dependency/packaging changes. `Interpreter.fromBuffer`, tensor metadata and an actual invocation must execute with a compatible prebuilt host C library. The upstream [binding loader](https://github.com/tensorflow/flutter-tflite/blob/main/lib/src/bindings/bindings.dart) is private and host-path-sensitive; verify the release's actual loader rather than assuming an override API. Public [Tensor.params documentation](https://pub.dev/documentation/tflite_flutter/latest/tflite_flutter/Tensor/params.html) says Android-only; use the model schema if host inspection cannot supply quantization. No SDK/pub-cache patching, private API hacks, silent platform-floor increases or native compilation. If compatible loading cannot be demonstrated, stop with evidence and request direction; dependency resolution/analyzer alone is not a pass.
- [ ] **Implement the descriptor and public runner.** Retain the verified asset/runtime pin, register assets/licenses and use public interpreter/tensor APIs for allocation, input-byte transfer, invocation, output snapshot and idempotent close. Reject mismatched metadata/length/out-of-range class IDs. The tool must now exercise this production runner, not merely the temporary probe.
- [ ] **Verify and record.** `flutter test tool/verify_room_model.dart --no-pub --reporter expanded` and focused descriptor tests must both exit 0 with real output. Record checksum, literal tensor/label data, host/runtime/library versions, actual room output and manually checked alignment in `docs/superpowers/plans/room-model-validation-report.md`. Freeze the inspector-derived numeric fixture expectations before later tasks. `flutter pub get` is allowed only during approved execution; it is not a native build. Native-device compatibility/quality remain unverified.

