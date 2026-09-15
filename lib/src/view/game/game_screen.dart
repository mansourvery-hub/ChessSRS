import 'package:chess_srs/src/model/common/id.dart';
import 'package:chess_srs/src/model/common/speed.dart';
import 'package:chess_srs/src/model/game/game.dart';
import 'package:chess_srs/src/model/game/game_controller.dart';
import 'package:chess_srs/src/model/settings/board_preferences.dart';
import 'package:chess_srs/src/network/socket.dart';
import 'package:chess_srs/src/utils/gestures_exclusion.dart';
import 'package:chess_srs/src/utils/immersive_mode.dart';
import 'package:chess_srs/src/utils/l10n_context.dart';
import 'package:chess_srs/src/utils/navigation.dart';
import 'package:chess_srs/src/view/game/exported_game_title.dart';
import 'package:chess_srs/src/view/game/game_body.dart';
import 'package:chess_srs/src/view/game/game_common_widgets.dart';
import 'package:chess_srs/src/view/game/game_loading_board.dart';
import 'package:chess_srs/src/view/game/game_screen_providers.dart';
import 'package:chess_srs/src/view/game/watcher_list_bottom_sheet.dart';
import 'package:chess_srs/src/widgets/adaptive_action_sheet.dart';
import 'package:chess_srs/src/widgets/bottom_bar.dart';
import 'package:chess_srs/src/widgets/feedback.dart';
import 'package:chess_srs/src/widgets/misc.dart';
import 'package:chess_srs/src/widgets/platform_context_menu_button.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Screen to play or watch an existing server game.
class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({required this.source, this.loadingPosition, this.lastMoveAt, super.key});

  final ExistingGameSource source;

  final LoadingParam? loadingPosition;

  /// The date of the last move played in the game. If null, the game is in progress.
  final DateTime? lastMoveAt;

  static Route<dynamic> buildRoute({
    required ExistingGameSource source,
    LoadingParam? loadingPosition,
    DateTime? lastMoveAt,
  }) {
    return buildScreenRoute(
      screen: GameScreen(source: source, loadingPosition: loadingPosition, lastMoveAt: lastMoveAt),
    );
  }

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

final _isRealTimePlayableGameProvider = FutureProvider.autoDispose.family<bool, GameFullId>((
  Ref ref,
  GameFullId gameId,
) async {
  final state = await ref.watch(gameControllerProvider(gameId).future);
  return state.game.meta.speed != Speed.correspondence && state.game.playable;
}, name: 'IsRealTimePlayableGameProvider');

class _GameScreenState extends ConsumerState<GameScreen> {
  final _whiteClockKey = GlobalKey(debugLabel: 'whiteClockOnGameScreen');
  final _blackClockKey = GlobalKey(debugLabel: 'blackClockOnGameScreen');
  final _boardKey = GlobalKey(debugLabel: 'boardOnGameScreen');

  @override
  Widget build(BuildContext context) {
    final boardPreferences = ref.watch(boardPreferencesProvider);

    switch (ref.watch(gameScreenLoaderProvider(widget.source))) {
      case AsyncData(value: GameCreatedState(:final createdGameId)):
        final isRealTimePlayingGame = ref.watch(
          _isRealTimePlayableGameProvider(createdGameId).select((s) => s.value ?? false),
        );

        final socketUri = GameController.socketUri(createdGameId);

        final body = PopScope(
          canPop: isRealTimePlayingGame != true,
          child: SafeArea(
            // view padding can change on Android when immersive mode is enabled, so to prevent any
            // board vertical shift, we set `maintainBottomViewPadding` to true.
            maintainBottomViewPadding: true,
            child: GameBody(
              gameId: createdGameId,
              loadingPosition: widget.loadingPosition,
              whiteClockKey: _whiteClockKey,
              blackClockKey: _blackClockKey,
              boardKey: _boardKey,
              onLoadGameCallback: (id) {
                if (mounted) {
                  ref.read(gameScreenLoaderProvider(widget.source).notifier).loadGame(id);
                }
              },
              onNewOpponentCallback: (_) {},
            ),
          ),
        );

        return Scaffold(
          resizeToAvoidBottomInset: false,
          appBar: AppBar(
            leading: isRealTimePlayingGame ? SocketPingRatingIcon(socketUri: socketUri) : null,
            title: _GameTitle(
              _StandaloneTitleVariant(id: createdGameId, lastMoveAt: widget.lastMoveAt),
              monitorSocket: isRealTimePlayingGame,
              socketUri: socketUri,
            ),
            actions: [_GameMenu(gameId: createdGameId)],
          ),
          body: Theme.of(context).platform == TargetPlatform.android
              ? AndroidGesturesExclusionWidget(
                  boardKey: _boardKey,
                  shouldExcludeGesturesOnFocusGained: isRealTimePlayingGame,
                  shouldSetImmersiveMode: boardPreferences.immersiveModeWhilePlaying ?? false,
                  child: body,
                )
              : body,
        );
      case AsyncError(error: final e, stackTrace: final s):
        debugPrint('SEVERE: [GameScreen] could not load game; $e\n$s');

        return Scaffold(
          resizeToAvoidBottomInset: false,
          appBar: AppBar(leading: const SocketPingRatingIcon()),
          body: const PopScope(
            child: LoadGameError('Sorry, we could not load the game. Please try again later.'),
          ),
        );
      case _:
        final loadingBoard = StandaloneGameLoadingContent(
          loadingParam: widget.loadingPosition,
          userActionsBar: const BottomBar.empty(),
        );

        return Scaffold(
          resizeToAvoidBottomInset: false,
          appBar: AppBar(leading: const SocketPingRatingIcon()),
          body: PopScope(canPop: false, child: WakelockWidget(child: loadingBoard)),
        );
    }
  }
}

sealed class _GameTitleVariant {
  const _GameTitleVariant();
}

final class _StandaloneTitleVariant extends _GameTitleVariant {
  const _StandaloneTitleVariant({required this.id, this.lastMoveAt});
  final GameFullId id;
  final DateTime? lastMoveAt;
}

class _GameTitle extends ConsumerWidget {
  const _GameTitle(this.variant, {this.monitorSocket = false, this.socketUri});

  final _GameTitleVariant variant;
  final bool monitorSocket;
  final Uri? socketUri;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (monitorSocket && ref.watch(socketPingProvider(socketUri)).rating == 0) {
      return AppBarTitleText(context.l10n.reconnecting);
    }

    return switch (variant) {
      _StandaloneTitleVariant(:final id, :final lastMoveAt) => _ExportedGameTitle(
        id: id,
        lastMoveAt: lastMoveAt,
      ),
    };
  }
}

final _gameMetaProvider = FutureProvider.autoDispose.family<GameMeta, GameFullId>((
  Ref ref,
  GameFullId gameId,
) async {
  return (await ref.read(gameControllerProvider(gameId).future)).game.meta;
}, name: 'GameMetaProvider');

class _ExportedGameTitle extends ConsumerWidget {
  const _ExportedGameTitle({required this.id, this.lastMoveAt});

  final GameFullId id;

  final DateTime? lastMoveAt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metaAsync = ref.watch(_gameMetaProvider(id));
    return metaAsync.when(
      data: (meta) => ExportedGameTitle(meta: meta, lastMoveAt: lastMoveAt),
      loading: () => const ExportedGameTitleLoading(),
      error: (error, _) => const SizedBox.shrink(),
    );
  }
}

/// App bar menu holding the game actions: spectators, bookmark, share and export.
class _GameMenu extends ConsumerWidget {
  const _GameMenu({required this.gameId});

  final GameFullId gameId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(gameControllerProvider(gameId)).value;
    if (gameState == null) return const SizedBox.shrink();

    return ContextMenuIconButton(
      icon: const Icon(Icons.more_horiz),
      semanticsLabel: context.l10n.menu,
      actions: [
        if (gameState.nbWatchers > 0)
          ContextMenuAction(
            icon: Icons.person_outline,
            label: 'Spectators (${gameState.nbWatchers})',
            onPressed: () {
              final s = ref.read(gameControllerProvider(gameId)).value;
              if (s == null) return;
              showModalBottomSheet<void>(
                context: context,
                builder: (_) =>
                    WatcherListBottomSheet(nbWatchers: s.nbWatchers, watcherNames: s.watcherNames),
              );
            },
          ),
        ContextMenuAction(
          icon: gameState.game.bookmarked == true
              ? Icons.bookmark_remove_outlined
              : Icons.bookmark_add_outlined,
          label: gameState.game.bookmarked == true
              ? context.l10n.mobileRemoveBookmark
              : context.l10n.bookmarkThisGame,
          onPressed: () => ref.read(gameControllerProvider(gameId).notifier).toggleBookmark(),
        ),
        ContextMenuAction(
          icon: Theme.of(context).platform == TargetPlatform.iOS
              ? Icons.ios_share_outlined
              : Icons.share_outlined,
          label: context.l10n.studyShareAndExport,
          onPressed: () => showAdaptiveActionSheet<void>(
            context: context,
            actions: makeFinishedGameShareBottomSheetActions(
              context,
              ref,
              gameId: gameId.gameId,
              orientation: gameState.game.youAre ?? Side.white,
              finished: gameState.game.finished,
            ),
          ),
        ),
      ],
    );
  }
}
