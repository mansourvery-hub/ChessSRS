import 'package:chess_srs/src/model/common/id.dart';
import 'package:chess_srs/src/model/common/perf.dart';
import 'package:chess_srs/src/model/user/leaderboard.dart';
import 'package:chess_srs/src/model/user/user.dart';
import 'package:chess_srs/src/model/user/user_repository.dart';
import 'package:chess_srs/src/network/http.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _kAutoCompleteDebounceTimer = Duration(milliseconds: 300);

final userProvider = FutureProvider.autoDispose.family<User, UserId>((Ref ref, UserId id) {
  return ref.read(userRepositoryProvider).getUser(id, withCanChallenge: true);
}, name: 'UserProvider');

final userPerfStatsProvider = FutureProvider.autoDispose.family<UserPerfStats, (UserId, Perf)>((
  Ref ref,
  (UserId, Perf) params,
) {
  return ref.read(userRepositoryProvider).getPerfStats(params.$1, params.$2);
}, name: 'UserPerfStatsProvider');

final top1Provider = FutureProvider.autoDispose<Top1Leaderboard>((Ref ref) {
  return ref.withAggregatorCacheFor(
    (client, aggregator) => UserRepository(client, aggregator).getTop1(),
    const Duration(hours: 12),
  );
}, name: 'Top1Provider');

final leaderboardProvider = FutureProvider.autoDispose<Leaderboard>((Ref ref) {
  return ref.withAggregatorCacheFor(
    (client, aggregator) => UserRepository(client, aggregator).getLeaderboard(),
    const Duration(hours: 2),
  );
}, name: 'LeaderboardProvider');

final onlineBotsProvider = FutureProvider.autoDispose<IList<User>>((Ref ref) {
  return ref.withAggregatorCacheFor(
    (client, aggregator) =>
        UserRepository(client, aggregator).getOnlineBots().then((bots) => bots.toIList()),
    const Duration(hours: 5),
  );
}, name: 'OnlineBotsProvider');

final autoCompleteUserProvider = FutureProvider.autoDispose.family<IList<LightUser>, String>((
  Ref ref,
  String term,
) async {
  // debounce calls as user might be typing
  var didDispose = false;
  ref.onDispose(() => didDispose = true);
  await Future<void>.delayed(_kAutoCompleteDebounceTimer);
  if (didDispose) {
    throw Exception('Cancelled');
  }

  return await ref.read(userRepositoryProvider).autocompleteUser(term);
}, name: 'AutoCompleteUserProvider');

final userRatingHistoryProvider = FutureProvider.autoDispose
    .family<IList<UserRatingHistoryPerf>, UserId>((Ref ref, UserId id) {
      return ref.withAggregatorCacheFor(
        (client, aggregator) => UserRepository(client, aggregator).getRatingHistory(id),
        const Duration(minutes: 1),
      );
    }, name: 'UserRatingHistoryProvider');

typedef CrosstableProviderParams = ({UserId userId1, UserId userId2, bool matchup});

final crosstableProvider = FutureProvider.autoDispose.family<Crosstable, CrosstableProviderParams>((
  Ref ref,
  CrosstableProviderParams params,
) {
  return ref
      .read(userRepositoryProvider)
      .getCrosstable(params.userId1, params.userId2, matchup: params.matchup);
}, name: 'CrosstableProvider');
