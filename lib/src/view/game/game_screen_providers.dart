import 'package:chess_srs/src/model/common/id.dart';
import 'package:chess_srs/src/model/game/game.dart';
import 'package:chess_srs/src/model/game/game_controller.dart';
import 'package:chess_srs/src/view/game/game_screen.dart';
import 'package:dartchess/dartchess.dart' show Side;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'game_screen_providers.freezed.dart';

/// The state of the [GameScreen].
sealed class GameScreenState {}

/// Game screen state when a game has been created or loaded.
@freezed
sealed class GameCreatedState with _$GameCreatedState implements GameScreenState {
  const GameCreatedState._();

  const factory GameCreatedState(GameFullId createdGameId) = _GameCreatedState;
}

/// The source from which the [GameScreen] was opened.
sealed class GameScreenSource {}

/// An existing game source for [GameScreen], identified by its [GameFullId].
@freezed
sealed class ExistingGameSource with _$ExistingGameSource implements GameScreenSource {
  const ExistingGameSource._();

  const factory ExistingGameSource(GameFullId id) = _ExistingGameSource;
}

/// A provider that loads or creates a game for the [GameScreen].
final gameScreenLoaderProvider = AsyncNotifierProvider.autoDispose
    .family<GameScreenLoaderNotifier, GameScreenState, GameScreenSource>(
      GameScreenLoaderNotifier.new,
      name: 'GameScreenLoaderProvider',
    );

class GameScreenLoaderNotifier extends AsyncNotifier<GameScreenState> {
  GameScreenLoaderNotifier(this.source);

  final GameScreenSource source;

  @override
  Future<GameScreenState> build() async {
    return switch (source) {
      ExistingGameSource(:final id) => GameCreatedState(id),
    };
  }

  /// Load a game from its id.
  void loadGame(GameFullId id) {
    state = AsyncValue.data(GameCreatedState(id));
  }
}

final isBoardTurnedProvider = NotifierProvider.autoDispose<IsBoardTurnedNotifier, bool>(
  IsBoardTurnedNotifier.new,
  name: 'IsBoardTurnedProvider',
);

class IsBoardTurnedNotifier extends Notifier<bool> {
  @override
  bool build() {
    return false;
  }

  void toggle() {
    state = !state;
  }
}

/// A provider that indicates whether the game is bookmarked.
final isGameBookmarkedProvider = FutureProvider.autoDispose.family<bool, GameFullId>((
  Ref ref,
  GameFullId gameId,
) async {
  return (await ref.watch(gameControllerProvider(gameId).future)).game.bookmarked ?? false;
}, name: 'IsGameBookmarkedProvider');

/// A provider that exposes data needed for sharing the game.
final gameShareDataProvider = FutureProvider.autoDispose
    .family<({bool finished, Side? pov}), GameFullId>((Ref ref, GameFullId gameId) async {
      final state = await ref.watch(gameControllerProvider(gameId).future);
      return (finished: state.game.finished, pov: state.game.youAre);
    }, name: 'GameShareDataProvider');

/// User game preferences, defined server-side.
final userGamePrefsProvider = FutureProvider.autoDispose
    .family<
      ({ServerGamePrefs? prefs, bool shouldConfirmMove, bool isZenModeEnabled, bool canAutoQueen}),
      GameFullId
    >((Ref ref, GameFullId gameId) async {
      final state = await ref.watch(gameControllerProvider(gameId).future);
      return (
        prefs: state.game.prefs,
        shouldConfirmMove: state.shouldConfirmMove,
        isZenModeEnabled: state.isZenModeEnabled,
        canAutoQueen: state.canAutoQueen,
      );
    }, name: 'UserGamePrefsProvider');
