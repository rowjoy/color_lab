import 'game_id.dart';
import 'game_profiles_state.dart';
import 'player_profile.dart';

/// A display-ready row in either the overall or per-game local leaderboard.
final class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.profileId,
    required this.profileName,
    required this.completedLevels,
    required this.coins,
    required this.isActive,
  });

  final int rank;
  final String profileId;
  final String profileName;
  final int completedLevels;
  final int coins;
  final bool isActive;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeaderboardEntry &&
          other.rank == rank &&
          other.profileId == profileId &&
          other.profileName == profileName &&
          other.completedLevels == completedLevels &&
          other.coins == coins &&
          other.isActive == isActive;

  @override
  int get hashCode => Object.hash(
    rank,
    profileId,
    profileName,
    completedLevels,
    coins,
    isActive,
  );
}

/// Ranks profiles by first-cleared levels across every game, then coins/name.
List<LeaderboardEntry> overallLeaderboard(GameProfilesState state) =>
    _rankProfiles(
      state,
      (profile) => profile.gameProgress.values.fold<int>(
        0,
        (total, progress) => total + progress.highestCompletedLevel,
      ),
    );

/// Ranks every local profile for [gameId], including profiles yet to play it.
List<LeaderboardEntry> gameLeaderboard(
  GameProfilesState state,
  GameId gameId,
) => _rankProfiles(
  state,
  (profile) => profile.gameProgress[gameId]?.highestCompletedLevel ?? 0,
);

List<LeaderboardEntry> _rankProfiles(
  GameProfilesState state,
  int Function(PlayerProfile profile) completedLevelsFor,
) {
  final rows = state.profiles.values
      .map(
        (profile) =>
            (profile: profile, completedLevels: completedLevelsFor(profile)),
      )
      .toList(growable: false);

  rows.sort((left, right) {
    final completedComparison = right.completedLevels.compareTo(
      left.completedLevels,
    );
    if (completedComparison != 0) return completedComparison;

    final coinComparison = right.profile.coins.compareTo(left.profile.coins);
    if (coinComparison != 0) return coinComparison;

    final nameComparison = left.profile.normalizedName.compareTo(
      right.profile.normalizedName,
    );
    if (nameComparison != 0) return nameComparison;
    return left.profile.id.compareTo(right.profile.id);
  });

  return List<LeaderboardEntry>.unmodifiable([
    for (var index = 0; index < rows.length; index++)
      LeaderboardEntry(
        rank: index + 1,
        profileId: rows[index].profile.id,
        profileName: rows[index].profile.name,
        completedLevels: rows[index].completedLevels,
        coins: rows[index].profile.coins,
        isActive: rows[index].profile.id == state.activeProfileId,
      ),
  ]);
}
