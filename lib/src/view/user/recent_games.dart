import 'package:chess_srs/src/model/game/exported_game.dart';
import 'package:chess_srs/src/model/game/game_history.dart';
import 'package:chess_srs/src/model/user/user.dart';
import 'package:chess_srs/src/network/connectivity.dart';
import 'package:chess_srs/src/styles/styles.dart';
import 'package:chess_srs/src/utils/l10n_context.dart';
import 'package:chess_srs/src/view/game/game_list_tile.dart';
import 'package:chess_srs/src/view/user/game_history_screen.dart';
import 'package:chess_srs/src/widgets/list.dart';
import 'package:chess_srs/src/widgets/shimmer.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A widget that show a list of recent games.
///
/// The [user] should be provided only if the games are for a specific user. If the
/// games are for the current logged in user, the [user] should be null.
class RecentGamesWidget extends ConsumerWidget {
  const RecentGamesWidget({
    required this.recentGames,
    required this.user,
    required this.nbOfGames,
    this.maxGamesToShow = kNumberOfRecentGames,
    super.key,
  });

  final LightUser? user;
  final AsyncValue<IList<LightExportedGameWithPov>> recentGames;
  final int nbOfGames;
  final int maxGamesToShow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isDeviceOnlineProvider);

    return recentGames.when(
      data: (data) {
        if (data.isEmpty) {
          return const SizedBox.shrink();
        }
        final list = data.take(maxGamesToShow);
        return ListSection(
          header: Text(context.l10n.recentGames),
          hasLeading: true,
          onHeaderTap: nbOfGames > list.length
              ? () {
                  Navigator.of(
                    context,
                  ).push(GameHistoryScreen.buildRoute(user: user, isOnline: isOnline));
                }
              : null,
          children: [for (final item in list) GameListTile(item: item)],
        );
      },
      error: (error, stackTrace) {
        debugPrint('SEVERE: [RecentGames] could not load recent games: $error\n$stackTrace');
        return const Padding(
          padding: Styles.bodySectionPadding,
          child: Text('Could not load recent games.'),
        );
      },
      loading: () => Shimmer(
        child: ShimmerLoading(
          isLoading: true,
          child: ListSection.loading(itemsNumber: 10, header: true, hasLeading: true),
        ),
      ),
    );
  }
}
