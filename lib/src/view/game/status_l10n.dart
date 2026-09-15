import 'package:chess_srs/src/model/common/chess.dart';
import 'package:chess_srs/src/model/game/game.dart';
import 'package:chess_srs/src/model/game/game_status.dart';
import 'package:chess_srs/src/utils/l10n_context.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/widgets.dart';

String gameStatusL10n(
  BuildContext context, {
  required Variant variant,
  required GameStatus status,
  required Position lastPosition,
  Side? winner,
  bool? isThreefoldRepetition,
}) {
  switch (status) {
    case GameStatus.started:
      return context.l10n.playingRightNow;
    case GameStatus.aborted:
      return context.l10n.gameAborted;
    case GameStatus.mate:
      return context.l10n.checkmate;
    case GameStatus.resign:
      return winner == Side.black ? context.l10n.whiteResigned : context.l10n.blackResigned;
    case GameStatus.stalemate:
      return context.l10n.stalemate;
    case GameStatus.timeout:
      return winner == null
          ? lastPosition.turn == Side.white
                ? '${context.l10n.whiteLeftTheGame} • ${context.l10n.draw}'
                : '${context.l10n.blackLeftTheGame} • ${context.l10n.draw}'
          : winner == Side.black
          ? context.l10n.whiteLeftTheGame
          : context.l10n.blackLeftTheGame;
    case GameStatus.insufficientMaterialClaim:
      return '${context.l10n.insufficientMaterial} • ${context.l10n.draw}';
    case GameStatus.draw:
      if (lastPosition.isInsufficientMaterial) {
        return '${context.l10n.insufficientMaterial} • ${context.l10n.draw}';
      } else if (isThreefoldRepetition == true) {
        return '${context.l10n.threefoldRepetition} • ${context.l10n.draw}';
      } else {
        return context.l10n.draw;
      }
    case GameStatus.outoftime:
      return winner == null
          ? lastPosition.turn == Side.white
                ? '${context.l10n.whiteTimeOut} • ${context.l10n.draw}'
                : '${context.l10n.blackTimeOut} • ${context.l10n.draw}'
          : winner == Side.black
          ? context.l10n.whiteTimeOut
          : context.l10n.blackTimeOut;
    case GameStatus.noStart:
      return winner == Side.black ? context.l10n.whiteDidntMove : context.l10n.blackDidntMove;
    case GameStatus.unknownFinish:
      return context.l10n.finished;
    case GameStatus.cheat:
      return context.l10n.cheatDetected;
    case GameStatus.variantEnd:
      switch (variant) {
        case Variant.kingOfTheHill:
          return context.l10n.kingInTheCenter;
        case Variant.racingKings:
          return context.l10n.raceFinished;
        case Variant.threeCheck:
          return context.l10n.threeChecks;
        default:
          return context.l10n.variantEnding;
      }
    default:
      return status.toString();
  }
}

class GameResult extends StatelessWidget {
  const GameResult({required this.game, super.key});

  final BaseGame game;

  @override
  Widget build(BuildContext context) {
    final showWinner = game.winner != null
        ? ' • ${game.winner == Side.white ? context.l10n.whiteIsVictorious : context.l10n.blackIsVictorious}'
        : '';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (game.status.value >= GameStatus.mate.value)
          Text(
            game.winner == null
                ? '½-½'
                : game.winner == Side.white
                ? '1-0'
                : '0-1',
            style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        const SizedBox(height: 6.0),
        Text(
          '${gameStatusL10n(context, variant: game.meta.variant, status: game.status, lastPosition: game.lastPosition, winner: game.winner, isThreefoldRepetition: game.isThreefoldRepetition)}$showWinner',
          style: const TextStyle(fontStyle: FontStyle.italic),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
