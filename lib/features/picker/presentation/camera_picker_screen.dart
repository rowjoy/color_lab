import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/color/color_engine.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../history/domain/saved_color.dart';
import '../../history/presentation/save_color_actions.dart';
import '../application/camera_session.dart';
import '../application/photo_acquisition_controller.dart';
import '../domain/photo_acquisition.dart';
import 'color_explorer.dart';

/// The route owns the native resource; no camera is created on the landing tab.
class CameraPickerScreen extends ConsumerStatefulWidget {
  const CameraPickerScreen({super.key});
  @override
  ConsumerState<CameraPickerScreen> createState() => _CameraPickerScreenState();
}

class _CameraPickerScreenState extends ConsumerState<CameraPickerScreen>
    with WidgetsBindingObserver {
  CameraSession? _session, _settingsSession, _openingSession;
  Future<void> _cleanup = Future.value();
  CameraFailure? _failure;
  RgbColor? _color;
  Offset _point = const Offset(.5, .5);
  int _epoch = 0;
  bool _ready = false, _active = true, _details = false, _picking = false;
  bool _retryOnResume = false;
  bool _routeActive = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]),
    );
    unawaited(_open());
  }

  bool _valid(int epoch) =>
      mounted && _active && _routeActive && epoch == _epoch;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final current = ModalRoute.of(context)?.isCurrent ?? true;
    if (_routeActive == current) return;
    _routeActive = current;
    if (!current && !_details) {
      if (_openingSession == null) ++_epoch;
      final session = _session;
      _session = null;
      if (session != null) _release(session);
      _ready = false;
      _color = null;
    } else if (current &&
        _active &&
        !_details &&
        !_picking &&
        _openingSession == null &&
        _failure == null) {
      unawaited(_open());
    }
  }

  Future<void> _open() async {
    final epoch = ++_epoch;
    final previous = _session;
    _session = null;
    if (previous != null) _release(previous);
    setState(() {
      _ready = false;
      _failure = null;
      _color = null;
    });
    await _cleanup;
    if (!_valid(epoch)) return;
    final session = ref.read(cameraSessionFactoryProvider)();
    _session = session;
    _settingsSession = session;
    _openingSession = session;
    try {
      await session.initialize();
      if (!_valid(epoch) || !identical(_session, session)) return;
      setState(() => _ready = true);
      await session.start(
        onColor: (color) {
          if (_valid(epoch)) setState(() => _color = color);
        },
        onError: (error) => _failed(error, epoch, session),
      );
    } on CameraFailure catch (error) {
      _failed(error, epoch, session);
    } catch (_) {
      _failed(
        const CameraFailure(CameraFailureKind.initialization),
        epoch,
        session,
      );
    } finally {
      if (identical(_openingSession, session)) _openingSession = null;
      // Resume waits for the interrupted permission result. A canceled grant
      // can reopen safely after cleanup; a denial remains until explicit retry.
      if (mounted &&
          _valid(epoch) &&
          _session == null &&
          _failure == null &&
          !_details &&
          !_picking &&
          (ModalRoute.of(context)?.isCurrent ?? true)) {
        unawaited(_open());
      }
    }
  }

  void _release(CameraSession session) {
    // Invalidate first; native teardown can finish after the widget has gone.
    _cleanup = _cleanup
        .then((_) => session.dispose())
        .catchError((Object _) {});
  }

  void _failed(CameraFailure error, int epoch, CameraSession session) {
    if (!mounted || epoch != _epoch) return;
    ++_epoch;
    if (identical(_session, session)) {
      _session = null;
      _release(session);
    }
    setState(() {
      _failure = error;
      _ready = false;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _active = true;
      if (_openingSession != null || (_failure != null && !_retryOnResume)) {
        return;
      }
      _retryOnResume = false;
      if (!_details &&
          !_picking &&
          (ModalRoute.of(context)?.isCurrent ?? true)) {
        unawaited(_open());
      }
    } else {
      _active = false;
      // Keep the pending decision's identity, while releasing its native owner.
      // initialize will still report permission denial after disposal.
      if (_openingSession == null) ++_epoch;
      final session = _session;
      _session = null;
      if (session != null) _release(session);
      if (mounted) {
        setState(() {
          _ready = false;
          _color = null;
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(SystemChrome.setPreferredOrientations([]));
    ++_epoch;
    final session = _session;
    _session = null;
    if (session != null) _release(session);
    super.dispose();
  }

  Future<void> _showDetails() async {
    final color = _color, session = _session;
    if (color == null || session == null || _details) return;
    _details = true;
    // Invalidate callbacks without releasing the frozen preview.
    final epoch = ++_epoch;
    try {
      await session.stop();
      if (!mounted ||
          !_valid(epoch) ||
          !(ModalRoute.of(context)?.isCurrent ?? true)) {
        return;
      }
      await showColorDetails(
        context,
        color,
        source: ColorSource.camera,
        heroTag: 'camera-selected-color',
      );
    } catch (_) {
      if (mounted && _active) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open this color. Please try again.'),
          ),
        );
      }
    } finally {
      _details = false;
      if (mounted &&
          _active &&
          !_picking &&
          (ModalRoute.of(context)?.isCurrent ?? true)) {
        await _open();
      }
    }
  }

  Future<void> _pickPhoto() async {
    if (_picking ||
        _details ||
        !_active ||
        !(ModalRoute.of(context)?.isCurrent ?? true)) {
      return;
    }
    final resumeCamera = _ready;
    final session = _session;
    ++_epoch;
    _session = null;
    setState(() {
      _picking = true;
      _ready = false;
      _color = null;
    });
    if (session != null) _release(session);
    try {
      await _cleanup;
      if (!mounted ||
          !_active ||
          !(ModalRoute.of(context)?.isCurrent ?? true)) {
        return;
      }
      final acquisition = ref.read(photoAcquisitionProvider.notifier);
      await acquisition.ensureRecovered();
      if (!mounted ||
          !_active ||
          !(ModalRoute.of(context)?.isCurrent ?? true)) {
        return;
      }
      final result = await acquisition.request(
        source: PhotoSource.gallery,
        destination: AcquisitionDestination.capture,
        isActive: () =>
            mounted && _active && (ModalRoute.of(context)?.isCurrent ?? true),
      );
      if (!mounted ||
          !_active ||
          !(ModalRoute.of(context)?.isCurrent ?? true)) {
        return;
      }
      if (result is Acquired) {
        Future<void>? navigation;
        await acquisition.claim(
          requestId: result.receipt.requestId,
          destination: AcquisitionDestination.capture,
          accept: (photo) {
            if (!mounted ||
                !_active ||
                !(ModalRoute.of(context)?.isCurrent ?? true)) {
              return false;
            }
            navigation = context.push<void>('/photo', extra: photo);
            return true;
          },
        );
        await navigation;
      } else if (result is AcquisitionBusy || result is AcquisitionFailed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result is AcquisitionBusy
                  ? 'Finish the pending photo request in Capture.'
                  : 'Could not prepare that photo. Return to Capture to retry.',
            ),
            action: SnackBarAction(
              label: 'Capture',
              onPressed: () => context.go('/capture'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _picking = false);
        if (resumeCamera &&
            _active &&
            (ModalRoute.of(context)?.isCurrent ?? true)) {
          await _open();
        }
      }
    }
  }

  void _exit() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/capture');
    }
  }

  Future<void> _settings() async {
    _retryOnResume = true;
    final opened = await _settingsSession?.openSettings() ?? false;
    if (!opened) _retryOnResume = false;
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Open your device settings to allow camera access.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _color == null
        ? null
        : ref.watch(colorNamerProvider).asData?.value.nearest(_color!).name;
    return Scaffold(
      backgroundColor: context.appColors.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final session = _session;
          void sample(Offset local) {
            if (!_ready || session == null) return;
            final point = Offset(
              (local.dx / constraints.maxWidth).clamp(0, 1),
              (local.dy / constraints.maxHeight).clamp(0, 1),
            );
            setState(() {
              _point = point;
              _color = null;
            });
            session.updateSamplePoint(
              x: point.dx,
              y: point.dy,
              viewportWidth: constraints.maxWidth,
              viewportHeight: constraints.maxHeight,
            );
          }

          if (_ready && session != null) {
            session.updateSamplePoint(
              x: _point.dx,
              y: _point.dy,
              viewportWidth: constraints.maxWidth,
              viewportHeight: constraints.maxHeight,
            );
          }
          return Stack(
            fit: StackFit.expand,
            children: [
              if (_ready && session != null) ...[
                GestureDetector(
                  key: const ValueKey('camera-preview'),
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (event) => sample(event.localPosition),
                  onPanUpdate: (event) => sample(event.localPosition),
                  child: ClipRect(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: 1000 * session.previewAspectRatio,
                        height: 1000,
                        child: session.buildPreview(),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: _point.dx * constraints.maxWidth - 26,
                  top: _point.dy * constraints.maxHeight - 26,
                  child: IgnorePointer(
                    child: Semantics(
                      label: 'Camera sampling point',
                      child: Hero(
                        tag: 'camera-selected-color',
                        child: Container(
                          key: const ValueKey('camera-reticle'),
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _color == null
                                ? Colors.transparent
                                : displayColor(_color!),
                            border: Border.all(color: Colors.white, width: 5),
                            boxShadow: const [
                              BoxShadow(color: Colors.black54, blurRadius: 4),
                            ],
                          ),
                          child: const Icon(
                            Icons.add_rounded,
                            size: 22,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              if (!_ready)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: _failure == null && _active
                        ? Semantics(
                            label: 'Starting camera',
                            child: const CircularProgressIndicator(),
                          )
                        : _failure == null
                        ? const SizedBox.shrink()
                        : SingleChildScrollView(child: _failureView()),
                  ),
                ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        IconCircleButton(
                          icon: Icons.arrow_back_rounded,
                          label: 'Back to Capture',
                          onPressed: _exit,
                        ),
                        const Spacer(),
                        const Flexible(
                          child: Chip(
                            label: Text(
                              'LIVE COLOR',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_ready)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: constraints.maxHeight * .52,
                        ),
                        child: SingleChildScrollView(
                          child: GlassBar(
                            borderRadius: AppRadii.large,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  _color?.hex ?? 'Finding your shade…',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineSmall,
                                ),
                                if (_color != null)
                                  Text(
                                    '${name ?? 'Your color'} · RGB ${_color!.red}, ${_color!.green}, ${_color!.blue}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                if (_color != null)
                                  Text(
                                    'HSL ${_color!.toHsl().hue.round()}°, ${(_color!.toHsl().saturation * 100).round()}%, ${(_color!.toHsl().lightness * 100).round()}%',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                const SizedBox(height: 12),
                                if (_color != null)
                                  SaveColorActions(
                                    color: _color!,
                                    name: name,
                                    source: ColorSource.camera,
                                  ),
                                const SizedBox(height: 8),
                                Wrap(
                                  alignment: WrapAlignment.spaceBetween,
                                  spacing: 8,
                                  children: [
                                    TextButton.icon(
                                      onPressed: _color == null
                                          ? null
                                          : _showDetails,
                                      icon: const Icon(
                                        Icons.info_outline_rounded,
                                      ),
                                      label: const Text('Color details'),
                                    ),
                                    TextButton.icon(
                                      onPressed: _picking ? null : _pickPhoto,
                                      icon: const Icon(Icons.photo_outlined),
                                      label: const Text('Choose photo'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _failureView() {
    final kind = _failure!.kind;
    final title = switch (kind) {
      CameraFailureKind.permissionDenied => 'Allow camera access',
      CameraFailureKind.permissionPermanentlyDenied ||
      CameraFailureKind.permissionRestricted => 'Camera access is off',
      CameraFailureKind.unavailable => 'No camera found',
      CameraFailureKind.unsupportedFormat =>
        'This camera format is not supported',
      _ => 'Could not start the camera',
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          Icons.camera_alt_outlined,
          size: 48,
          color: context.appColors.textSecondary,
        ),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        const Text(
          'Use your camera to explore live colors, or choose a photo.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        if (kind == CameraFailureKind.permissionPermanentlyDenied ||
            kind == CameraFailureKind.permissionRestricted) ...[
          SecondaryButton(label: 'Open settings', onPressed: _settings),
          const SizedBox(height: 12),
        ],
        PrimaryButton(label: 'Try again', onPressed: _picking ? null : _open),
        TextButton(
          onPressed: _picking ? null : _pickPhoto,
          child: const Text('Choose a photo instead'),
        ),
      ],
    );
  }
}
