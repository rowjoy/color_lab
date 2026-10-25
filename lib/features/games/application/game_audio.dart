import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Short, offline effects played by the native platform audio API.
///
/// Most effects are synthesized; Water Sort uses a bundled pour recording.
abstract final class GameAudio {
  static const _channel = MethodChannel('com.colorlab/game_audio');

  static Future<void> play(String effect) async {
    try {
      await _channel.invokeMethod<void>('play', {'effect': effect});
    } on MissingPluginException catch (error) {
      debugPrint('Game audio channel is not registered: $error');
    } on PlatformException catch (error) {
      debugPrint('Native game audio failed: $error');
    }
  }

  static Future<void> playWaterPour(int amount) async {
    final boundedAmount = amount.clamp(1, 4);
    try {
      await _channel.invokeMethod<void>('play', {
        'effect': 'waterPour',
        'amount': boundedAmount,
        'durationMs': 450 + 260 * boundedAmount,
      });
    } on MissingPluginException catch (error) {
      debugPrint('Game audio channel is not registered: $error');
    } on PlatformException catch (error) {
      debugPrint('Native game audio failed: $error');
    }
  }
}
