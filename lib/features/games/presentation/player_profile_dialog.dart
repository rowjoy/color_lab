import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../application/game_profiles_provider.dart';
import '../domain/game_progression_engine.dart';
import '../domain/player_profile.dart';

Future<PlayerProfile?> showPlayerProfileDialog(
  BuildContext context, {
  PlayerProfile? profile,
  bool requiredProfile = false,
}) => showDialog<PlayerProfile>(
  context: context,
  barrierDismissible: !requiredProfile,
  builder: (_) =>
      PlayerProfileDialog(profile: profile, requiredProfile: requiredProfile),
);

/// Creates a local player or renames an existing one.
class PlayerProfileDialog extends ConsumerStatefulWidget {
  const PlayerProfileDialog({
    super.key,
    this.profile,
    this.requiredProfile = false,
  }) : assert(profile == null || !requiredProfile);

  final PlayerProfile? profile;
  final bool requiredProfile;

  @override
  ConsumerState<PlayerProfileDialog> createState() =>
      _PlayerProfileDialogState();
}

class _PlayerProfileDialogState extends ConsumerState<PlayerProfileDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.profile?.name ?? '',
  );
  String? _nameError;
  String? _saveError;
  bool _busy = false;

  bool get _isRename => widget.profile != null;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    try {
      PlayerProfile.normalizedNameFor(_name.text);
    } on ArgumentError {
      setState(() {
        _nameError = 'Use 2–20 visible characters.';
        _saveError = null;
      });
      return;
    }

    setState(() {
      _busy = true;
      _nameError = null;
      _saveError = null;
    });
    try {
      final controller = ref.read(gameProfilesProvider.notifier);
      final saved = _isRename
          ? await controller.renameProfile(
              profileId: widget.profile!.id,
              name: _name.text,
            )
          : await controller.createProfile(name: _name.text);
      if (mounted) Navigator.of(context).pop(saved);
    } on GameProgressionException catch (error) {
      if (!mounted) return;
      setState(() {
        if (error.code == GameProgressionError.duplicateProfileName) {
          _nameError = 'That player name already exists.';
        } else if (error.code == GameProgressionError.invalidProfile) {
          _nameError = 'Use 2–20 visible characters.';
        } else {
          _saveError = 'This player could not be saved. Try again.';
        }
      });
    } on Object {
      if (mounted) {
        setState(
          () => _saveError = 'This player could not be saved. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !widget.requiredProfile && !_busy,
    child: AlertDialog(
      scrollable: true,
      title: Text(_isRename ? 'Rename player' : 'Create your player'),
      content: SizedBox(
        width: AppSpacing.huge * 6,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isRename
                  ? 'Choose a name that is unique on this device.'
                  : 'Your levels, coins, scores, and badges stay with this player.',
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              key: const ValueKey('player-profile-name'),
              controller: _name,
              enabled: !_busy,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: 'Player name',
                hintText: 'Me',
                errorText: _nameError,
                errorMaxLines: 3,
              ),
              onChanged: (_) {
                if (_nameError != null || _saveError != null) {
                  setState(() {
                    _nameError = null;
                    _saveError = null;
                  });
                }
              },
              onSubmitted: (_) => _save(),
            ),
            if (_saveError != null) ...[
              Semantics(liveRegion: true, child: Text(_saveError!)),
              const SizedBox(height: AppSpacing.md),
            ],
            PrimaryButton(
              key: const ValueKey('save-player-profile'),
              label: _isRename ? 'Save name' : 'Create player',
              isLoading: _busy,
              onPressed: _busy ? null : _save,
            ),
            if (!widget.requiredProfile) ...[
              const SizedBox(height: AppSpacing.md),
              SecondaryButton(
                key: const ValueKey('cancel-player-profile'),
                label: 'Cancel',
                onPressed: _busy ? null : () => Navigator.of(context).pop(),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
