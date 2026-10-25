import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme.dart';
import '../application/game_profiles_provider.dart';
import '../domain/player_profile.dart';
import 'player_profile_dialog.dart';

Future<void> showProfileManagementSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const FractionallySizedBox(
        heightFactor: .88,
        child: ProfileManagementSheet(),
      ),
    );

/// Local player creation, selection, rename, and deletion controls.
class ProfileManagementSheet extends ConsumerStatefulWidget {
  const ProfileManagementSheet({super.key});

  @override
  ConsumerState<ProfileManagementSheet> createState() =>
      _ProfileManagementSheetState();
}

class _ProfileManagementSheetState
    extends ConsumerState<ProfileManagementSheet> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() operation) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await operation();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Player profiles could not be updated.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _select(PlayerProfile profile) => _run(() async {
    await ref
        .read(gameProfilesProvider.notifier)
        .setActiveProfile(profileId: profile.id);
  });

  Future<void> _rename(PlayerProfile profile) async {
    if (_busy) return;
    await showPlayerProfileDialog(context, profile: profile);
  }

  Future<void> _create() async {
    if (_busy) return;
    await showPlayerProfileDialog(context);
  }

  Future<void> _delete(PlayerProfile profile) async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete ${profile.name}?'),
        content: const Text(
          'This removes this player’s local levels, coins, and badges.',
        ),
        actions: [
          TextButton(
            key: const ValueKey('cancel-delete-profile'),
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('confirm-delete-profile'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await _run(() async {
      await ref
          .read(gameProfilesProvider.notifier)
          .deleteProfile(profileId: profile.id);
      if (!mounted) return;
      final state = ref.read(gameProfilesProvider).value;
      if (state != null && state.profiles.isEmpty) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final profiles = ref.watch(gameProfilesProvider);
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        bottom: AppSpacing.xl + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Player profiles',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Each player keeps separate levels, coins, scores, and badges.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: profiles.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Center(
                child: Text(
                  'Player profiles could not be opened.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              data: (state) => ListView.separated(
                itemCount: state.profiles.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final profile = state.profiles.values.elementAt(index);
                  final active = profile.id == state.activeProfileId;
                  return _ProfileRow(
                    profile: profile,
                    active: active,
                    enabled: !_busy,
                    onSelect: () => _select(profile),
                    onRename: () => _rename(profile),
                    onDelete: () => _delete(profile),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            key: const ValueKey('create-player-profile'),
            onPressed: _busy ? null : _create,
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: const Text('Create player'),
          ),
        ],
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.profile,
    required this.active,
    required this.enabled,
    required this.onSelect,
    required this.onRename,
    required this.onDelete,
  });

  final PlayerProfile profile;
  final bool active;
  final bool enabled;
  final VoidCallback onSelect;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
    child: Row(
      children: [
        Expanded(
          child: Semantics(
            button: true,
            label: active
                ? '${profile.name}, current player'
                : 'Switch to ${profile.name}',
            child: ExcludeSemantics(
              child: InkWell(
                key: ValueKey('select-profile-${profile.id}'),
                borderRadius: BorderRadius.circular(12),
                onTap: enabled && !active ? onSelect : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.md,
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(child: Text(profile.name.characters.first)),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          profile.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      if (active)
                        Icon(
                          Icons.check_circle_rounded,
                          key: ValueKey('active-profile-${profile.id}'),
                          color: Theme.of(context).colorScheme.primary,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Semantics(
          button: true,
          label: 'Rename ${profile.name}',
          child: ExcludeSemantics(
            child: IconButton(
              key: ValueKey('rename-profile-${profile.id}'),
              tooltip: 'Rename ${profile.name}',
              onPressed: enabled ? onRename : null,
              icon: const Icon(Icons.edit_outlined),
            ),
          ),
        ),
        Semantics(
          button: true,
          label: 'Delete ${profile.name}',
          child: ExcludeSemantics(
            child: IconButton(
              key: ValueKey('delete-profile-${profile.id}'),
              tooltip: 'Delete ${profile.name}',
              onPressed: enabled ? onDelete : null,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ),
        ),
      ],
    ),
  );
}
