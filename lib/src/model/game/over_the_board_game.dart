import 'package:chess_srs/src/model/common/eval.dart';
import 'package:chess_srs/src/model/common/id.dart';
import 'package:chess_srs/src/model/game/game.dart';
import 'package:chess_srs/src/model/game/game_status.dart';
import 'package:chess_srs/src/model/game/player.dart';
import 'package:chess_srs/src/model/user/user.dart';
import 'package:chess_srs/src/utils/string.dart';
import 'package:dartchess/dartchess.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'over_the_board_game.freezed.dart';
part 'over_the_board_game.g.dart';

/// An offline game played in real life by two human players on the same device.
///
/// See [PlayableGame] for a game that is played online.
@Freezed(fromJson: true, toJson: true)
abstract class OverTheBoardGame with BaseGame, _$OverTheBoardGame, LocalGame, IndexableSteps {
  const OverTheBoardGame._();

  factory OverTheBoardGame.fromJson(Map<String, dynamic> json) => _$OverTheBoardGameFromJson(json);

  @override
  Player get white => Player(
    onGame: true,
    user: LightUser(id: UserId(Side.white.name), name: Side.white.name.capitalize()),
  );

  @override
  Player get black => Player(
    onGame: true,
    user: LightUser(id: UserId(Side.black.name), name: Side.black.name.capitalize()),
  );

  @override
  Side? get youAre => null;

  @override
  IList<ExternalEval>? get evals => null;

  bool get abortable => playable && lastPosition.fullmoves <= 1;

  bool get resignable => playable && !abortable;
  bool get drawable => playable && lastPosition.fullmoves >= 2;

  @Assert('steps.isNotEmpty')
  factory OverTheBoardGame({
    required StringId id,
    @JsonKey(fromJson: stepsFromJson, toJson: stepsToJson) required IList<GameStep> steps,
    required GameMeta meta,
    required String? initialFen,
    required GameStatus status,
    Side? winner,
    bool? isThreefoldRepetition,
  }) = _OverTheBoardGame;
}
