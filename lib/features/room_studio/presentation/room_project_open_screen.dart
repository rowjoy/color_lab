import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/adaptive_page.dart';
import '../../../l10n/l10n.dart';
import '../application/room_project_session_controller.dart';
import 'room_mask_screen.dart';
import 'room_project_actions.dart';
import 'room_project_storage_notice.dart';

/// The ID remains in the URI for restart restoration. Only a successful Open
/// (or Continue of that same retained draft) bypasses new-photo model setup.
class RoomProjectOpenScreen extends ConsumerStatefulWidget {
  const RoomProjectOpenScreen({
    super.key,
    required this.projectId,
    this.isSetupContinuation = false,
    this.compareRequested = false,
  });
  final String projectId;
  final bool compareRequested;

  /// Only the setup gate mounts this continuation after explicit permission.
  final bool isSetupContinuation;
  @override
  ConsumerState<RoomProjectOpenScreen> createState() =>
      _RoomProjectOpenScreenState();
}

class _RoomProjectOpenScreenState extends ConsumerState<RoomProjectOpenScreen> {
  RoomProjectActionFailure? _failure;
  bool _opened = false;
  bool _retargeting = false;
  bool _opening = false;
  bool _scheduled = false;
  int _operation = 0;

  @override
  void initState() {
    super.initState();
    ref.listenManual(roomProjectSessionProvider, (_, next) {
      // A new photo created by this visible editor becomes the restorable ID.
      // Changes made while this route is covered belong to the covering route.
      if (_opened &&
          mounted &&
          next != null &&
          next.projectId != widget.projectId &&
          _ownsRoute) {
        _retargeting = true;
        Future.microtask(() {
          if (mounted && _ownsRoute) {
            context.replace(
              Uri(
                path: '/room/masks',
                queryParameters: {
                  'project': next.projectId,
                  if (widget.compareRequested) 'compare': '1',
                },
              ).toString(),
            );
          }
        });
      }
    });
    _scheduleOpen();
  }

  bool get _ownsRoute =>
      mounted &&
      (ModalRoute.of(context)?.isCurrent ?? false) &&
      GoRouter.of(context).state.uri.queryParameters[widget.isSetupContinuation
              ? 'setupProject'
              : 'project'] ==
          widget.projectId;

  @override
  void didUpdateWidget(RoomProjectOpenScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.projectId != oldWidget.projectId ||
        widget.isSetupContinuation != oldWidget.isSetupContinuation) {
      _operation++;
      _opened = false;
      _retargeting = false;
      _failure = null;
      _scheduleOpen();
    }
  }

  void _scheduleOpen() {
    if (_opening || _scheduled) return;
    _scheduled = true;
    Future.microtask(() {
      _scheduled = false;
      if (mounted) _open();
    });
  }

  Future<void> _open() async {
    if (!mounted || !_ownsRoute || _opening) return;
    final id = widget.projectId;
    final operation = ++_operation;
    bool current() =>
        mounted &&
        operation == _operation &&
        widget.projectId == id &&
        _ownsRoute;
    setState(() {
      _opening = true;
      _opened = false;
      _failure = null;
    });
    try {
      final opened = await ref
          .read(roomProjectActionsProvider.notifier)
          .open(id, isCurrent: current);
      if (current()) setState(() => _opened = opened);
    } on RoomProjectActionException catch (error) {
      if (current()) setState(() => _failure = error.failure);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: Navigator.of(context).canPop(),
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop && !Navigator.of(context).canPop()) {
        context.go('/rooms/projects');
      }
    },
    child: _buildPage(context),
  );

  Widget _buildPage(BuildContext context) {
    final l10n = context.l10n;
    final session = ref.watch(roomProjectSessionProvider);
    final ownsRoute = _ownsRoute;
    if (!_opening &&
        !_retargeting &&
        ownsRoute &&
        ((!_opened && _failure == null) ||
            (_opened && session?.projectId != widget.projectId))) {
      // A retained page can become current after another project was edited.
      // Re-enter through the same unsaved/CAS-safe session boundary.
      _opened = false;
      _scheduleOpen();
    }
    if (_opened && (session?.projectId == widget.projectId || _retargeting)) {
      return RoomMaskScreen(
        projectId: widget.projectId,
        compareRequested: widget.compareRequested,
      );
    }
    return Scaffold(
      body: AdaptivePage(
        maxContentWidth: 640,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: IconButton(
                tooltip: l10n.back,
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/rooms/projects');
                  }
                },
                icon: const Icon(Icons.arrow_back),
              ),
            ),
            if (_failure case final failure?) ...[
              Text(
                l10n.roomProjectOpenError,
                key: const ValueKey('room-project-open-error'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              Semantics(
                liveRegion: true,
                child: Text(roomProjectActionFailureText(context, failure)),
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: const ValueKey('room-project-open-retry'),
                onPressed: _open,
                child: Text(l10n.tryAgain),
              ),
              if (session != null)
                OutlinedButton(
                  onPressed: () => context.go(
                    '/rooms/project/${Uri.encodeComponent(session.projectId)}',
                  ),
                  child: Text(l10n.roomProjectContinue),
                ),
            ] else
              Semantics(liveRegion: true, child: Text(l10n.roomProjectOpening)),
            OutlinedButton(
              key: const ValueKey('room-project-open-library'),
              onPressed: () => context.go('/rooms/projects'),
              child: Text(l10n.roomProjectsTitle),
            ),
          ],
        ),
      ),
    );
  }
}
