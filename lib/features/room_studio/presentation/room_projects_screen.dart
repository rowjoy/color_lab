import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/layout/adaptive_page.dart';
import '../../../l10n/l10n.dart';
import '../application/room_project_session_controller.dart';
import '../application/room_projects_providers.dart';
import '../domain/room_project.dart';
import 'room_project_actions.dart';
import 'room_project_save_status.dart';
import 'room_project_storage_notice.dart';

class RoomProjectsScreen extends ConsumerStatefulWidget {
  const RoomProjectsScreen({super.key});
  @override
  ConsumerState<RoomProjectsScreen> createState() => _RoomProjectsScreenState();
}

class _RoomProjectsScreenState extends ConsumerState<RoomProjectsScreen> {
  RoomProjectActionFailure? _failure;
  bool _showingAction = false;

  void _open(String id) =>
      context.push('/rooms/project/${Uri.encodeComponent(id)}');

  Future<void> _menu(RoomProjectSummary project) async {
    if (_showingAction || ref.read(roomProjectActionsProvider)) return;
    setState(() {
      _showingAction = true;
      _failure = null;
    });
    try {
      final selection = await showModalBottomSheet<_ProjectMenu>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (sheetContext) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  project.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                for (final item in [
                  _ProjectMenu.rename,
                  _ProjectMenu.duplicate,
                ]) ...[
                  OutlinedButton(
                    key: ValueKey('room-project-${item.name}'),
                    onPressed: () => Navigator.pop(sheetContext, item),
                    child: Text(
                      item == _ProjectMenu.rename
                          ? context.l10n.roomProjectRename
                          : context.l10n.roomProjectDuplicate,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                OutlinedButton(
                  key: const ValueKey('room-project-compare'),
                  onPressed: null,
                  child: Text(context.l10n.roomProjectCompare),
                ),
                Text(context.l10n.roomProjectCompareUnavailable),
                const SizedBox(height: 16),
                OutlinedButton(
                  key: const ValueKey('room-project-delete'),
                  onPressed: () =>
                      Navigator.pop(sheetContext, _ProjectMenu.delete),
                  child: Text(context.l10n.roomProjectDelete),
                ),
              ],
            ),
          ),
        ),
      );
      if (!mounted || selection == null) return;
      if (selection == _ProjectMenu.duplicate) {
        var name = project.name;
        while (context.l10n.roomProjectCopyName(name).length > 80 &&
            name.isNotEmpty) {
          final runes = name.runes.toList();
          name = String.fromCharCodes(runes.take(runes.length - 1));
        }
        await ref
            .read(roomProjectActionsProvider.notifier)
            .duplicate(project, name: context.l10n.roomProjectCopyName(name));
      } else {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => _ProjectActionDialog(
            project: project,
            deleting: selection == _ProjectMenu.delete,
          ),
        );
      }
    } on RoomProjectActionException catch (error) {
      if (mounted) setState(() => _failure = error.failure);
    } finally {
      if (mounted) setState(() => _showingAction = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final projects = ref.watch(roomProjectsProvider);
    final busy = ref.watch(roomProjectActionsProvider);
    final session = ref.watch(roomProjectSessionProvider);
    return Scaffold(
      body: AdaptivePage(
        maxContentWidth: 1200,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton(
                  key: const ValueKey('room-projects-back'),
                  tooltip: l10n.back,
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/rooms');
                    }
                  },
                  icon: const Icon(Icons.arrow_back),
                ),
                const Spacer(),
                IconButton(
                  key: const ValueKey('room-projects-refresh'),
                  tooltip: l10n.roomProjectsRefresh,
                  onPressed: busy
                      ? null
                      : () => ref.invalidate(roomProjectsProvider),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            Text(
              l10n.roomProjectsTitle,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            Text(l10n.roomProjectsDescription),
            const SizedBox(height: 20),
            if (busy) ...[
              Semantics(liveRegion: true, child: Text(l10n.roomProjectWorking)),
              const LinearProgressIndicator(),
              const SizedBox(height: 16),
            ],
            if (_failure case final failure?) ...[
              Semantics(
                liveRegion: true,
                child: Text(roomProjectActionFailureText(context, failure)),
              ),
              const SizedBox(height: 16),
            ],
            if (session != null &&
                !(projects.value?.records.any(
                      (p) => p.projectId == session.projectId,
                    ) ??
                    false)) ...[
              Text(session.name, style: Theme.of(context).textTheme.titleLarge),
              RoomProjectSaveStatusView(
                session: session,
                onRetry: () =>
                    ref.read(roomProjectSessionProvider.notifier).retrySave(),
              ),
              FilledButton(
                onPressed: busy ? null : () => _open(session.projectId),
                child: Text(l10n.roomProjectContinue),
              ),
              const SizedBox(height: 20),
            ],
            projects.when(
              skipLoadingOnRefresh: false,
              loading: () => Semantics(
                liveRegion: true,
                child: Text(l10n.roomProjectsLoading),
              ),
              error: (_, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.roomProjectsError,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(l10n.roomProjectsRetryBody),
                  OutlinedButton(
                    key: const ValueKey('room-projects-retry'),
                    onPressed: () {
                      if (ref.read(roomProjectRepositoryProvider).hasError) {
                        ref.invalidate(roomProjectRepositoryProvider);
                      }
                      ref.invalidate(roomProjectsProvider);
                    },
                    child: Text(l10n.tryAgain),
                  ),
                ],
              ),
              data: (snapshot) {
                final records = [...snapshot.records]
                  ..sort((a, b) {
                    final updated = b.updatedAt.compareTo(a.updatedAt);
                    return updated == 0
                        ? a.projectId.compareTo(b.projectId)
                        : updated;
                  });
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (snapshot.corruptRecords.isNotEmpty) ...[
                      Semantics(
                        liveRegion: true,
                        child: Text(l10n.roomProjectsCorrupt),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (records.isEmpty) ...[
                      Text(
                        snapshot.corruptRecords.isEmpty
                            ? l10n.roomProjectsEmpty
                            : l10n.roomProjectsNoneReadable,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(l10n.roomProjectsEmptyBody),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: busy
                            ? null
                            : () => context.push('/room/masks'),
                        child: Text(l10n.roomUsePhoto),
                      ),
                      OutlinedButton(
                        onPressed: busy
                            ? null
                            : () => context.push('/room/illustrated'),
                        child: Text(l10n.roomTryIllustrated),
                      ),
                    ] else
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final columns = constraints.maxWidth >= 1100
                              ? 3
                              : constraints.maxWidth >= 600
                              ? 2
                              : 1;
                          final width =
                              (constraints.maxWidth - 16 * (columns - 1)) /
                              columns;
                          return Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: [
                              for (final project in records)
                                SizedBox(
                                  width: width,
                                  child: RoomProjectCard(
                                    key: ValueKey(
                                      'room-project-${project.projectId}',
                                    ),
                                    project: project,
                                    onOpen: busy || _showingAction
                                        ? null
                                        : () => _open(project.projectId),
                                    onMenu: busy || _showingAction
                                        ? null
                                        : () => _menu(project),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class RoomProjectCard extends ConsumerWidget {
  const RoomProjectCard({
    super.key,
    required this.project,
    required this.onOpen,
    required this.onMenu,
  });
  final RoomProjectSummary project;
  final VoidCallback? onOpen, onMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final active = ref.watch(roomProjectSessionProvider);
    final session = active?.projectId == project.projectId ? active : null;
    final name = session?.name ?? project.name;
    final warning = session?.recoveryWarning ?? project.warning;
    final date = DateFormat.yMMMd(
      l10n.localeName,
    ).add_jm().format(project.updatedAt.toLocal());
    Widget fallback() => Semantics(
      container: true,
      label: l10n.roomProjectThumbnailUnavailable(name),
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.photo_outlined),
            Text(
              l10n.roomProjectThumbnailUnavailable(name),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
    return Card(
      semanticContainer: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              container: true,
              header: true,
              child: Text(name, style: Theme.of(context).textTheme.titleLarge),
            ),
            const SizedBox(height: 8),
            Semantics(
              container: true,
              child: Text(l10n.roomProjectUpdated(date)),
            ),
            const SizedBox(height: 12),
            if (project.thumbnailPng case final thumbnail?)
              Image.memory(
                thumbnail,
                height: 132,
                fit: BoxFit.cover,
                semanticLabel: l10n.roomProjectThumbnail(name),
                errorBuilder: (_, _, _) => fallback(),
              )
            else
              fallback(),
            const SizedBox(height: 12),
            if (warning != null) ...[
              RoomProjectStorageNotice(warning: warning),
              const SizedBox(height: 12),
            ],
            if (session != null) ...[
              RoomProjectSaveStatusView(
                session: session,
                onRetry: () =>
                    ref.read(roomProjectSessionProvider.notifier).retrySave(),
              ),
              const SizedBox(height: 12),
            ],
            Semantics(
              container: true,
              label: session == null
                  ? l10n.roomProjectOpenLabel(name)
                  : l10n.roomProjectContinueLabel(name),
              button: true,
              excludeSemantics: true,
              enabled: onOpen != null,
              onTap: onOpen,
              child: FilledButton(
                key: ValueKey('room-project-open-${project.projectId}'),
                onPressed: onOpen,
                child: Text(
                  session == null
                      ? l10n.roomProjectOpen
                      : l10n.roomProjectContinue,
                ),
              ),
            ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: IconButton(
                key: ValueKey('room-project-menu-${project.projectId}'),
                tooltip: l10n.roomProjectMenu(name),
                onPressed: onMenu,
                icon: const Icon(Icons.more_horiz),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _ProjectMenu { rename, duplicate, delete }

class _ProjectActionDialog extends ConsumerStatefulWidget {
  const _ProjectActionDialog({required this.project, required this.deleting});
  final RoomProjectSummary project;
  final bool deleting;
  @override
  ConsumerState<_ProjectActionDialog> createState() =>
      _ProjectActionDialogState();
}

class _ProjectActionDialogState extends ConsumerState<_ProjectActionDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.project.name,
  );
  RoomProjectActionFailure? _failure;
  bool _busy = false;
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      final actions = ref.read(roomProjectActionsProvider.notifier);
      if (widget.deleting) {
        await actions.delete(widget.project.projectId, confirmed: true);
      } else {
        await actions.rename(widget.project, _name.text);
      }
      if (mounted) Navigator.pop(context);
    } on RoomProjectActionException catch (error) {
      if (mounted) setState(() => _failure = error.failure);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        scrollable: true,
        title: Text(
          widget.deleting
              ? l10n.roomProjectDeleteTitle(widget.project.name)
              : l10n.roomProjectRename,
        ),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.deleting)
              Text(l10n.roomProjectDeleteBody)
            else
              TextField(
                key: const ValueKey('room-project-name'),
                controller: _name,
                enabled: !_busy,
                decoration: InputDecoration(labelText: l10n.roomProjectName),
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _submit(),
              ),
            if (_failure case final failure?)
              Semantics(
                liveRegion: true,
                child: Text(roomProjectActionFailureText(context, failure)),
              ),
            if (_busy)
              Semantics(liveRegion: true, child: Text(l10n.roomProjectWorking)),
          ],
        ),
        actions: [
          TextButton(
            key: ValueKey(
              'room-project-${widget.deleting ? 'delete' : 'rename'}-cancel',
            ),
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: Text(l10n.roomProjectCancel),
          ),
          FilledButton(
            key: ValueKey(
              'room-project-${widget.deleting ? 'delete' : 'rename'}-confirm',
            ),
            onPressed: _busy ? null : _submit,
            child: Text(
              widget.deleting ? l10n.roomProjectDelete : l10n.roomProjectRename,
            ),
          ),
        ],
      ),
    );
  }
}
