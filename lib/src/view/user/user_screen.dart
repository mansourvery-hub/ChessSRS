import 'package:chess_srs/src/model/auth/auth_controller.dart';
import 'package:chess_srs/src/model/common/id.dart';
import 'package:chess_srs/src/model/game/game_filter.dart';
import 'package:chess_srs/src/model/relation/relation_repository.dart';
import 'package:chess_srs/src/model/user/user.dart';
import 'package:chess_srs/src/model/user/user_repository.dart';
import 'package:chess_srs/src/network/connectivity.dart';
import 'package:chess_srs/src/network/http.dart';
import 'package:chess_srs/src/styles/styles.dart';
import 'package:chess_srs/src/utils/l10n_context.dart';
import 'package:chess_srs/src/utils/navigation.dart';
import 'package:chess_srs/src/utils/share.dart';
import 'package:chess_srs/src/view/user/game_history_screen.dart';
import 'package:chess_srs/src/view/user/perf_cards.dart';
import 'package:chess_srs/src/view/user/recent_games.dart';
import 'package:chess_srs/src/view/user/user_activity.dart';
import 'package:chess_srs/src/view/user/user_profile.dart';
import 'package:chess_srs/src/widgets/buttons.dart';
import 'package:chess_srs/src/widgets/feedback.dart';
import 'package:chess_srs/src/widgets/haptic_refresh_indicator.dart';
import 'package:chess_srs/src/widgets/list.dart';
import 'package:chess_srs/src/widgets/platform.dart';
import 'package:chess_srs/src/widgets/user.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' show ClientException;
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

final _userScreenDataProvider = FutureProvider.autoDispose.family<UserScreenData, UserId>(
  (ref, id) => ref.read(userRepositoryProvider).getUserScreenData(id),
  name: 'UserScreenDataProvider',
);

class UserScreen extends ConsumerStatefulWidget {
  const UserScreen({required this.user, super.key});

  final LightUser user;

  static Route<dynamic> buildRoute(LightUser user) {
    return buildScreenRoute(screen: UserScreen(user: user));
  }

  @override
  ConsumerState<UserScreen> createState() => _UserScreenState();
}

class _UserScreenState extends ConsumerState<UserScreen> {
  bool isLoading = false;

  void setIsLoading(bool value) {
    if (mounted) {
      setState(() {
        isLoading = value;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final userScreenData = ref.watch(_userScreenDataProvider(widget.user.id));
    final updatedLightUser = userScreenData.maybeWhen(
      data: (data) => data.user.lightUser.copyWith(isOnline: data.isOnline),
      orElse: () => null,
    );
    final seenAt = userScreenData.maybeWhen(data: (data) => data.user.seenAt, orElse: () => null);
    return PlatformScaffold(
      appBar: PlatformAppBar(
        titleSpacing: 0,
        title: UserAppBarTitleWidget(
          user: updatedLightUser ?? widget.user,
          isOnline: updatedLightUser?.isOnline == true,
          seenAt: seenAt,
        ),
        actions: [
          if (isLoading) const PlatformAppBarLoadingIndicator(),
          SemanticIconButton(
            icon: const PlatformShareIcon(),
            semanticsLabel: 'Share profile',
            onPressed: () =>
                launchShareDialog(context, ShareParams(uri: lichessUri('/@/${widget.user.name}'))),
          ),
        ],
      ),
      body: userScreenData.when(
        data: (data) => _UserProfileListView(
          data,
          isLoading,
          setIsLoading,
          onRefresh: () => ref.refresh(_userScreenDataProvider(widget.user.id).future),
        ),
        loading: () => const Center(child: CircularProgressIndicator.adaptive()),
        error: (error, _) {
          if (error is ClientException && error.message.contains('404')) {
            return Center(
              child: Text(
                textAlign: TextAlign.center,
                context.l10n.usernameNotFound(widget.user.name),
                style: Styles.bold,
              ),
            );
          }
          return FullScreenRetryRequest(
            onRetry: () => ref.invalidate(_userScreenDataProvider(widget.user.id)),
          );
        },
      ),
    );
  }
}

class _UserProfileListView extends ConsumerWidget {
  const _UserProfileListView(
    this.data,
    this.isLoading,
    this.setIsLoading, {
    required this.onRefresh,
  });

  final UserScreenData data;
  final bool isLoading;
  final void Function(bool value) setIsLoading;
  final RefreshCallback onRefresh;

  String _scoreDisplay(double score) {
    final integerPart = score.truncate();
    final decimalPart = score - integerPart;

    return integerPart == 0 && decimalPart == 0.5
        ? '½'
        : '$integerPart${decimalPart == 0.5 ? '½' : ''}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UserScreenData(:user, :recentGames, :activity, :isPlayingLive, :crosstable) = data;

    final isOnline = ref.watch(isDeviceOnlineProvider);
    final nbOfGames = user.count?.all ?? 0;
    final authUser = ref.watch(authControllerProvider);

    if (user.disabled == true) {
      return Center(child: Text(context.l10n.settingsThisAccountIsClosed, style: Styles.bold));
    }

    Future<void> userAction(Future<void> Function() action) async {
      setIsLoading(true);
      try {
        await action.call().then((_) => ref.invalidate(_userScreenDataProvider(user.id)));
      } finally {
        setIsLoading(false);
      }
    }

    return HapticRefreshIndicator(
      edgeOffset: Theme.of(context).platform == TargetPlatform.iOS
          ? MediaQuery.paddingOf(context).top + kToolbarHeight
          : 0.0,
      onRefresh: onRefresh,
      child: ListView(
        children: [
          UserProfileWidget(user: user),
          PerfCards(user: user, isMe: false),
          ListSection(
            hasLeading: true,
            children: [
              if (authUser != null && crosstable != null && (crosstable.nbGames) > 0) ...[
                () {
                  final crosstableData = crosstable;
                  final currentUserScore = crosstableData.users[authUser.user.id] ?? 0;
                  final otherUserScore = crosstableData.users[user.id] ?? 0;

                  return ListTile(
                    title: Text(
                      context.l10n.yourScore(
                        '${_scoreDisplay(currentUserScore)} - ${_scoreDisplay(otherUserScore)}',
                      ),
                    ),
                    leading: const Icon(Icons.scoreboard_outlined),
                    onTap: () {
                      Navigator.of(context).push(
                        GameHistoryScreen.buildRoute(
                          user: authUser.user,
                          isOnline: isOnline,
                          gameFilter: GameFilterState(opponent: user),
                        ),
                      );
                    },
                  );
                }(),
              ],
              if (authUser != null) ...[
                if (user.followable == true && user.following != true)
                  ListTile(
                    leading: const Icon(Icons.person_add_outlined),
                    title: Text(context.l10n.follow),
                    onTap: isLoading
                        ? null
                        : () => userAction(
                            () => ref.read(relationRepositoryProvider).follow(user.id),
                          ),
                  )
                else if (user.following == true)
                  ListTile(
                    leading: const Icon(Icons.person_remove_outlined),
                    title: Text(context.l10n.unfollow),
                    onTap: isLoading
                        ? null
                        : () => userAction(
                            () => ref.read(relationRepositoryProvider).unfollow(user.id),
                          ),
                  ),
                if (user.following != true && user.blocking != true)
                  ListTile(
                    leading: const Icon(Icons.block_outlined),
                    title: Text(context.l10n.block),
                    onTap: isLoading
                        ? null
                        : () =>
                              userAction(() => ref.read(relationRepositoryProvider).block(user.id)),
                  )
                else if (user.blocking == true)
                  ListTile(
                    leading: const Icon(Icons.block_outlined),
                    title: Text(context.l10n.unblock),
                    onTap: isLoading
                        ? null
                        : () => userAction(
                            () => ref.read(relationRepositoryProvider).unblock(user.id),
                          ),
                  ),
                ListTile(
                  leading: const Icon(Icons.report_problem_outlined),
                  title: Text(context.l10n.reportXToModerators(user.username)),
                  onTap: () {
                    launchUrl(
                      lichessUri('/report', {'username': user.id, 'login': authUser.user.id}),
                    );
                  },
                ),
              ],
            ],
          ),
          UserActivityWidget(activity: AsyncData(activity), user: user.lightUser),
          RecentGamesWidget(
            recentGames: AsyncData(recentGames),
            nbOfGames: nbOfGames,
            user: user.lightUser,
          ),
        ],
      ),
    );
  }
}
