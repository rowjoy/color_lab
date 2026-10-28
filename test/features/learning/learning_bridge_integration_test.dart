import 'package:color_lab/core/color/color_models.dart';
import 'package:color_lab/features/learning/domain/learning_palette_copy.dart';
import 'package:color_lab/features/room_studio/application/illustrated_room_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('palette bridge owns value copies after its source is deleted', () {
    final source = [
      RgbColor.fromHex('#112233'),
      RgbColor.fromHex('#445566'),
      RgbColor.fromHex('#778899'),
    ];
    final payload = LearningPaletteCopy(
      colors: source,
      returnLocation: '/learn/lesson/hue',
    );

    expect(payload.colors.first, isNot(same(source.first)));
    source.clear();

    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(illustratedRoomProvider.notifier)
        .applyLearningPalette(payload);
    final colors = container.read(illustratedRoomProvider).activeDraft!.colors!;

    expect(colors.wall.hex, '#112233');
    expect(colors.ceiling.hex, '#445566');
    expect(colors.floor.hex, '#778899');
    expect(colors.furniture.hex, '#112233');
    expect(payload.returnLocation, '/learn/lesson/hue');
  });

  test('palette bridge respects the retained dirty-room guard', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(illustratedRoomProvider.notifier);
    controller.applyLearningPalette(
      LearningPaletteCopy(
        colors: [RgbColor.fromHex('#123456')],
        returnLocation: '/learn/notebook',
      ),
    );

    expect(
      () => controller.applyLearningPalette(
        LearningPaletteCopy(
          colors: [RgbColor.fromHex('#ABCDEF')],
          returnLocation: '/my-work',
        ),
      ),
      throwsA(isA<IllustratedRoomDraftConflict>()),
    );
  });

  test('both value-copy destinations are available after Plan 07', () {
    expect(
      isLearningPaletteDestinationAvailable(
        LearningPaletteDestination.illustratedRoom,
      ),
      isTrue,
    );
    expect(
      isLearningPaletteDestinationAvailable(
        LearningPaletteDestination.coloring,
      ),
      isTrue,
    );
  });
}
