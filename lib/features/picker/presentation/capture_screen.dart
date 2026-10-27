import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/l10n.dart';
import '../../../core/color/color_engine.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../shell/presentation/studio_page.dart';
import '../application/photo_picker_service.dart';
import '../application/photo_acquisition_controller.dart';
import '../domain/photo_acquisition.dart';
import 'color_explorer.dart';

class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({super.key});
  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen> {
  bool _picking = false;

  bool get _isCaptureCurrent =>
      (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState ==
              AppLifecycleState.resumed) &&
      (ModalRoute.of(context)?.isCurrent ?? false) &&
      GoRouter.of(context).state.uri.path == '/capture';

  Future<void> _pick() async {
    if (_picking || !_isCaptureCurrent) return;
    setState(() => _picking = true);
    try {
      final result = await ref
          .read(photoAcquisitionProvider.notifier)
          .request(
            source: PhotoSource.gallery,
            destination: AcquisitionDestination.capture,
            isActive: () => mounted && _isCaptureCurrent,
          );
      if (!mounted || !_isCaptureCurrent) return;
      if (result is Acquired) {
        await _continuePhoto(result.receipt);
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _continuePhoto(AcquisitionReceipt receipt) async {
    if (!mounted || !_isCaptureCurrent) return;
    Future<void>? navigation;
    await ref
        .read(photoAcquisitionProvider.notifier)
        .claim(
          requestId: receipt.requestId,
          destination: AcquisitionDestination.capture,
          accept: (photo) {
            if (!mounted || !_isCaptureCurrent) return false;
            navigation = context.push<void>('/photo', extra: photo);
            return true;
          },
        );
    await navigation;
  }

  Future<void> _dismissUnfinished() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dismiss unfinished request?'),
        content: const Text(
          'This clears only the unfinished photo request. Your photos and saved colors are kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep request'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Dismiss request'),
          ),
        ],
      ),
    );
    if (!mounted || !_isCaptureCurrent || confirmed != true) return;
    await ref.read(photoAcquisitionProvider.notifier).discardUntrustedIntent();
  }

  Future<void> _settings() async {
    final opened = await ref.read(photoPickerServiceProvider).openSettings();
    if (mounted && !opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Open your device settings to allow photo access.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final acquisition = ref.watch(photoAcquisitionProvider);
    final receipt = acquisition.pendingReceipt;
    final error = acquisition.failure;
    final blocked =
        _picking ||
        acquisition.phase != AcquisitionPhase.ready ||
        receipt != null ||
        acquisition.hasUntrustedIntent;
    return StudioPage(
      name: 'Capture',
      children: [
        Text(
          'A CURIOUS EYE. ENDLESS POSSIBILITY.',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            letterSpacing: 1.5,
            color: context.appColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text('See the world', style: Theme.of(context).textTheme.displaySmall),
        Text(
          'in a new shade.',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Find a color that feels like you.\nThen see where it takes you.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: context.appColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        const _ColorStudy(),
        const SizedBox(height: AppSpacing.xxl),
        PrimaryButton(
          label: 'Open camera',
          icon: Icons.camera_alt_outlined,
          onPressed: _picking
              ? null
              : () {
                  context.push('/camera');
                },
        ),
        const SizedBox(height: AppSpacing.md),
        SecondaryButton(
          label: 'Pick a photo',
          icon: Icons.photo_outlined,
          isLoading: _picking,
          onPressed: blocked ? null : _pick,
        ),
        if (receipt != null &&
            receipt.destination != AcquisitionDestination.room)
          SecondaryButton(
            icon: Icons.restore_rounded,
            label: receipt.recovered
                ? 'Continue recovered photo'
                : 'Continue selected photo',
            onPressed: acquisition.phase == AcquisitionPhase.ready
                ? () => _continuePhoto(receipt)
                : null,
          ),
        if (receipt != null &&
            receipt.destination != AcquisitionDestination.capture)
          SecondaryButton(
            label: 'Continue in Room',
            icon: Icons.chair_outlined,
            onPressed: () => context.go('/room'),
          ),
        if (acquisition.hasUntrustedIntent && receipt == null)
          SecondaryButton(
            label: 'Dismiss unfinished request',
            icon: Icons.close_rounded,
            onPressed: acquisition.phase == AcquisitionPhase.ready
                ? _dismissUnfinished
                : null,
          ),
        if (acquisition.phase == AcquisitionPhase.storageError)
          SecondaryButton(
            label: 'Retry photo request',
            icon: Icons.refresh_rounded,
            onPressed: () =>
                ref.read(photoAcquisitionProvider.notifier).retryStorage(),
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                Text(switch (error) {
                  AcquisitionFailureKind.permissionDenied =>
                    'Photo access is off. Allow access in Settings or choose a different photo.',
                  AcquisitionFailureKind.cameraUnavailable =>
                    context.l10n.roomCameraUnavailable,
                  AcquisitionFailureKind.unsupported =>
                    context.l10n.roomPhotoUnsupported,
                  AcquisitionFailureKind.tooLarge =>
                    'That photo is too large. Choose a smaller copy.',
                  AcquisitionFailureKind.invalidImage =>
                    'This photo could not be read. Try a JPEG or PNG image.',
                  AcquisitionFailureKind.processing =>
                    'We could not prepare that photo. Please try another.',
                  AcquisitionFailureKind.unavailable =>
                    'The photo picker is unavailable. Please try again.',
                  AcquisitionFailureKind.storage =>
                    'We could not save the photo request. Please retry.',
                  AcquisitionFailureKind.recovery =>
                    'The unfinished photo could not be recovered. You can choose another photo.',
                }, style: TextStyle(color: context.appColors.error)),
                if (error == AcquisitionFailureKind.permissionDenied)
                  TextButton(
                    onPressed: _settings,
                    child: const Text('Open photo settings'),
                  ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        SecondaryButton(
          label: 'Explore a color',
          icon: Icons.north_east_rounded,
          onPressed: () {
            showColorEntry(context);
          },
        ),
        const SizedBox(height: AppSpacing.xxxl),
        SectionHeader(
          title: 'Follow your curiosity',
          trailing: Text(
            '01 — 04',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: context.appColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        StudioCard(
          child: Column(
            children: [
              _DiscoverRow(
                icon: Icons.palette_outlined,
                title: 'A palette for every mood',
                subtitle: 'Small collections. Beautiful possibilities.',
                onTap: () => context.go('/palette'),
              ),
              Divider(
                color: context.appColors.outline,
                height: AppSpacing.xxxl,
              ),
              _DiscoverRow(
                icon: Icons.science_outlined,
                title: 'Get to know a color',
                subtitle: 'Play with hue, lightness and color values.',
                onTap: () => context.go('/lab'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        Text(
          'Your photos and colors stay on your device.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: context.appColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _DiscoverRow extends StatelessWidget {
  const _DiscoverRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(AppRadii.small),
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Icon(icon, color: context.appColors.textSecondary),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.appColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          const Icon(Icons.arrow_outward_rounded),
        ],
      ),
    ),
  );
}

class _ColorStudy extends StatelessWidget {
  const _ColorStudy();

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Color study with lilac, butter yellow and sage swatches',
    image: true,
    child: ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.large),
        child: AspectRatio(
          aspectRatio: 1.22,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final h = constraints.maxHeight;
              return ColoredBox(
                color: context.appColors.surfaceElevated,
                child: Stack(
                  children: [
                    Positioned(
                      right: -w * .08,
                      top: -h * .25,
                      child: Container(
                        width: w * .65,
                        height: w * .65,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: displayColor(RgbColor.fromHex('#D8D5EA')),
                        ),
                      ),
                    ),
                    Positioned(
                      left: w * .09,
                      top: h * .11,
                      child: Transform.rotate(
                        angle: -math.pi / 12,
                        child: _PaperSwatch(
                          width: w * .43,
                          height: h * .73,
                          color: RgbColor.fromHex('#E8DAA9'),
                          label: 'BUTTER',
                          code: '#E8DAA9',
                        ),
                      ),
                    ),
                    Positioned(
                      right: w * .09,
                      top: h * .2,
                      child: Transform.rotate(
                        angle: math.pi / 18,
                        child: _PaperSwatch(
                          width: w * .43,
                          height: h * .73,
                          color: RgbColor.fromHex('#B2A4D4'),
                          label: 'LILAC HAZE',
                          code: '#B2A4D4',
                        ),
                      ),
                    ),
                    Positioned(
                      left: w * .05,
                      bottom: h * .08,
                      child: Container(
                        width: w * .2,
                        height: w * .2,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: displayColor(RgbColor.fromHex('#809886')),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
}

class _PaperSwatch extends StatelessWidget {
  const _PaperSwatch({
    required this.width,
    required this.height,
    required this.color,
    required this.label,
    required this.code,
  });
  final double width;
  final double height;
  final RgbColor color;
  final String label;
  final String code;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    padding: const EdgeInsets.all(AppSpacing.sm),
    decoration: BoxDecoration(
      color: context.appColors.surface,
      borderRadius: BorderRadius.circular(AppRadii.small),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 4,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: displayColor(color),
              borderRadius: BorderRadius.circular(AppRadii.small),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: FittedBox(
            alignment: Alignment.centerLeft,
            fit: BoxFit.scaleDown,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelSmall),
                Text(
                  code,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: context.appColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
