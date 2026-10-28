import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/l10n.dart';
import '../application/illustrated_room_controller.dart';
import '../application/illustrated_room_export_controller.dart';
import '../application/illustrated_room_export_request.dart';
import '../application/illustrated_room_palette_card_encoder.dart';
import '../application/room_image_export_service.dart';
import 'illustrated_room_surface_picker.dart';

String illustratedRoomExportMessage(
  AppLocalizations l10n,
  IllustratedRoomExportResult result,
) => switch (result) {
  IllustratedRoomExportSuccess() => l10n.roomExportSaved,
  IllustratedRoomExportShared(:final result) => switch (result) {
    RoomShareResult.completed => l10n.roomExportShared,
    RoomShareResult.dismissed => l10n.roomExportDismissed,
    RoomShareResult.unavailable => l10n.roomExportUnavailable,
  },
  IllustratedRoomExportFailed(:final failure) => switch (failure) {
    IllustratedRoomExportFailure.accessDenied => l10n.roomExportAccess,
    IllustratedRoomExportFailure.notEnoughSpace => l10n.roomExportCapacity,
    IllustratedRoomExportFailure.shareFailed => l10n.roomExportShareFailed,
    IllustratedRoomExportFailure.interrupted => l10n.roomExportInterrupted,
    IllustratedRoomExportFailure.notColored ||
    IllustratedRoomExportFailure.renderFailed ||
    IllustratedRoomExportFailure.unsupportedFormat => l10n.roomExportInvalid,
    IllustratedRoomExportFailure.unsupportedPlatform ||
    IllustratedRoomExportFailure.unexpected => l10n.roomExportSaveFailed,
  },
};

class IllustratedRoomExportControls extends ConsumerWidget {
  const IllustratedRoomExportControls({super.key, required this.templateId});
  final String templateId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(illustratedRoomProvider).draftFor(templateId);
    if (draft == null) return const SizedBox.shrink();
    final busy = ref.watch(illustratedRoomExportProvider).isBusy;
    final l10n = context.l10n;
    Future<void> export(
      BuildContext buttonContext, {
      required bool card,
      required bool share,
    }) async {
      IllustratedRoomExportResult result;
      final request = IllustratedRoomExportRequest(
        ownsRequest: () =>
            context.mounted &&
            (ModalRoute.of(context)?.isCurrent ?? true) &&
            ref.read(illustratedRoomProvider).activeTemplateId == templateId,
      );
      try {
        final captured = ref
            .read(illustratedRoomProvider)
            .draftFor(templateId)!;
        final palette = card
            ? IllustratedRoomPaletteCard.fromDraft(
                captured,
                labelFor: (id) => roomRegionName(l10n, id),
                limitation: l10n.illustratedPalettePreviewLimit,
                textDirection: Directionality.of(context),
                textScale: MediaQuery.textScalerOf(
                  context,
                ).scale(1).clamp(1, 2),
              )
            : null;
        final controller = ref.read(illustratedRoomExportProvider.notifier);
        if (share) {
          final box = buttonContext.findRenderObject()! as RenderBox;
          result = await controller.share(
            captured,
            paletteCard: palette,
            origin: box.localToGlobal(Offset.zero) & box.size,
            title: l10n.roomExportTitle('TintAtlas'),
            isCurrent: () => request.isCurrent,
          );
        } else {
          result = await controller.saveToGallery(
            captured,
            paletteCard: palette,
            isCurrent: () => request.isCurrent,
          );
        }
      } catch (_) {
        result = const IllustratedRoomExportFailed(
          IllustratedRoomExportFailure.renderFailed,
        );
      } finally {
        request.dispose();
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(illustratedRoomExportMessage(l10n, result))),
      );
    }

    Widget output(bool card) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          card ? l10n.roomExportPaletteCard : l10n.roomExportArtwork,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final share in [false, true])
              Builder(
                builder: (buttonContext) => OutlinedButton(
                  key: ValueKey(
                    'room-export-${card ? 'palette' : 'artwork'}-${share ? 'share' : 'save'}',
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: busy || (card && draft.displayAssignments == null)
                      ? null
                      : () => export(buttonContext, card: card, share: share),
                  child: Text(
                    share ? l10n.roomExportShare : l10n.roomExportSave,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.roomExportDisplayed),
        Text(l10n.roomExportEffects),
        if (busy)
          Semantics(liveRegion: true, child: Text(l10n.roomExportSaving)),
        output(false),
        const SizedBox(height: 12),
        output(true),
      ],
    );
  }
}
