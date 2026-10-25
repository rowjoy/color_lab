import 'package:color_lab/features/games/application/game_audio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.colorlab/game_audio');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('bundles the Water Sort pour recording', () async {
    final audio = await rootBundle.load('assets/audio/pour_bottle_clean.mp3');

    expect(audio.lengthInBytes, greaterThan(0));
  });

  test('sends the selected sound effect to native audio', () async {
    await GameAudio.play('pour');

    expect(calls, hasLength(1));
    expect(calls.single.method, 'play');
    expect(calls.single.arguments, {'effect': 'pour'});
  });

  test('sends water-pour amount to native audio', () async {
    await GameAudio.playWaterPour(3);

    expect(calls, hasLength(1));
    expect(calls.single.method, 'play');
    expect(calls.single.arguments, {
      'effect': 'waterPour',
      'amount': 3,
      'durationMs': 1230,
    });
  });

  test('clamps water-pour amount to the supported tube range', () async {
    await GameAudio.playWaterPour(9);

    expect(calls.single.arguments, {
      'effect': 'waterPour',
      'amount': 4,
      'durationMs': 1490,
    });
  });

  test('does not fail when native sound is unavailable', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);

    await expectLater(GameAudio.play('tap'), completes);
  });
}
