# Room verification execution guard

## Observed correction

The user prohibited APK builds in our workflow. Our workflow built no APK, native
application or TensorFlow Lite library. The user subsequently confirmed an
independent build/run at2026-10-22 02:24+0600; newer APK copies were first observed
at SHA-256`00896beade2a82a2f99908e203b1f4c56a07daa8ef678dcd7f13d85a220d2ae7`.
The final check observes another artifact update at10:37:35+0600, SHA-256
`eb36f749379d33e82644e6c61861647ccb88c685479ff780bd3bd2959fa0a3ae`.
Both copies remain untouched by this workflow; see `room-final-verification.md`.
However, the broader earlier claim that no native compilation
occurred was inaccurate: normal Dart/Flutter dependency hooks compiled the
existing transitive `objective_c9.5.0` macOS host support library at2026-10-22
01:35:35 and01:35:39+0600. The actual cached hook logs and generated dylib
timestamps establish this. Later gates reused those cached outputs. No SDK or
pub-cache source was patched, and no host library belongs in the source ZIP.

## Remaining checks

Use the direct VM, not `dart run`, for the smoke wrapper:

```sh
/usr/bin/sandbox-exec -f /private/tmp/color-lab-no-native.XP4L3M/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/cache/dart-sdk/bin/dartvm tool/run_room_model_smoke.dart --flutter-root /Users/jamirulislam/Applications/flutter
```

The wrapper imports only dart libraries; its explicit children compile Flutter
kernel bytecode and stage existing prebuilts. Root executed this exact guarded
VM command successfully: real default-factory PASS, same model/mask hashes and
all1,091,840 aligned pixels; no Dartdev build-hook phase. Stage
`color-lab-room-smoke.qfqTLm`, evidence `color-lab-task5-evidence.OwdgCm`.

Prefix every remaining Flutter test/preview command, preserving its arguments:

```sh
/usr/bin/sandbox-exec -f /private/tmp/color-lab-no-native.XP4L3M/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub ...
```

The profile permits prebuilts and Dart bytecode execution but denies known
native-compiler/build executables. Its actual Xcode clang denial was tested:
`clang --version` under the profile exits71, Operation not permitted. If cached
dependency inputs change and a hook attempts compilation, tests must fail; do
not bypass the barrier or delete caches. Normal SDK metadata access may require
the tool's approved escalation; keep the inner profile in that command.

`--no-test-assets` does not disable hooks: installed Flutter test.dart481 builds
native assets before the asset-bundle guard. The inspected BuildInfo flag has no
supported test CLI override. `dart --disable-dart-dev` also did not bypass the
installed Dartdev; the separate `dartvm` executable is required. Normal analyzer
and read-only formatter commands remain usable.

Task10 retains the identical profile under `tool/deny-native-compilers.sb` and
includes it with documentation/source. Portable commands from the project root:

```sh
COLOR_LAB_FLUTTER_ROOT=/path/to/flutter
/usr/bin/sandbox-exec -f tool/deny-native-compilers.sb "$COLOR_LAB_FLUTTER_ROOT/bin/flutter" test --no-pub --reporter expanded
/usr/bin/sandbox-exec -f tool/deny-native-compilers.sb "$COLOR_LAB_FLUTTER_ROOT/bin/flutter" test tool/render_previews.dart --no-pub --reporter expanded
/usr/bin/sandbox-exec -f tool/deny-native-compilers.sb "$COLOR_LAB_FLUTTER_ROOT/bin/cache/dart-sdk/bin/dartvm" tool/run_room_model_smoke.dart --flutter-root "$COLOR_LAB_FLUTTER_ROOT"
```

A fresh clone
without required native test assets may fail closed; this guard is not a way to
create those assets without compilation, nor proof of phone compatibility.

Read-only SDK audit: `/root/dart_hook_audit`; root independently checked actual
hook timestamps/logs, compiler denial and guarded real-model execution. This is
a verification-procedure correction, not a new product feature or permission to
build an APK.
