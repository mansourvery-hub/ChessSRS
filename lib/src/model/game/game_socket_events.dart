import 'package:chess_srs/src/model/common/chess.dart';
import 'package:chess_srs/src/model/common/eval.dart';
import 'package:chess_srs/src/model/common/id.dart';
import 'package:chess_srs/src/model/game/player.dart';
import 'package:chess_srs/src/utils/json.dart';
import 'package:dartchess/dartchess.dart';
import 'package:deep_pick/deep_pick.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'game_socket_events.freezed.dart';

@freezed
sealed class ServerEvalEvent with _$ServerEvalEvent {
  const ServerEvalEvent._();

  const factory ServerEvalEvent({
    required IList<ExternalEval> evals,
    required Map<String, dynamic> tree,
    ServerAnalysis? analysis,
    GameDivision? division,
    required bool isAnalysisComplete,
  }) = _ServerEvalEvent;

  factory ServerEvalEvent.fromJson(Map<String, dynamic> json) =>
      _serverEvalEventFromPick(pick(json).required());
}

ServerEvalEvent _serverEvalEventFromPick(RequiredPick pick) {
  final tree = pick('tree').asMapOrThrow<String, dynamic>();
  Map<String, dynamic>? node = tree;
  final List<ExternalEval> evals = [];

  bool isAnalysisIncomplete = false;

  String? nextVariation;

  while (node != null) {
    final ply = node['ply'] as int;
    final san = node['san'] as String?;
    final children = node['children'] as List<dynamic>?;
    final firstChild = children?.firstOrNull as Map<String, dynamic>?;
    final eval = node['eval'] as Map<String, dynamic>?;

    if (eval == null && firstChild != null && ply <= 300 && ply > 0) {
      isAnalysisIncomplete = true;
    }

    final glyphs = node['glyphs'] as List<dynamic>?;
    final glyph = glyphs?.first as Map<String, dynamic>?;
    final comments = node['comments'] as List<dynamic>?;
    final comment = comments?.first as Map<String, dynamic>?;
    final judgment = glyph != null && comment != null
        ? (name: _nagToJugdmentName(glyph['id'] as int), comment: comment['text'] as String)
        : null;

    final variation = nextVariation;

    final buffer = StringBuffer();
    if (children != null && children.length > 1) {
      Map<String, dynamic>? variationNode = children[1] as Map<String, dynamic>;
      while (variationNode != null) {
        final san = variationNode['san'] as String;
        if (buffer.isEmpty) {
          buffer.write(san);
        } else {
          buffer.write(' $san');
        }
        final nestedChildren = variationNode['children'] as List<dynamic>?;
        if (nestedChildren != null && nestedChildren.isNotEmpty) {
          variationNode = nestedChildren.first as Map<String, dynamic>;
        } else {
          break;
        }
      }
    }
    nextVariation = buffer.isEmpty ? null : buffer.toString();
    // make it compatible with lichess API GET /game/export which doesn't return
    // an eval of the starting position
    // also make sure to not add an empty eval for checkmate (or stalemate) which
    // would be the leaf node with no eval
    if (san != null && (eval != null || firstChild != null)) {
      evals.add(
        ExternalEval(
          cp: eval?['cp'] as int?,
          mate: eval?['mate'] as int?,
          bestMove: eval?['best'] as String?,
          judgment: judgment,
          variation: variation,
        ),
      );
    }
    node = firstChild;
  }

  return ServerEvalEvent(
    tree: tree,
    evals: evals.lock,
    analysis: pick('analysis').letOrNull(
      (it) => (
        id: GameId(it('id').asStringOrThrow()),
        white: it('white').letOrThrow(
          (pa) => PlayerAnalysis(
            inaccuracies: pa('inaccuracy').asIntOrThrow(),
            mistakes: pa('mistake').asIntOrThrow(),
            blunders: pa('blunder').asIntOrThrow(),
            acpl: pa('acpl').asIntOrNull(),
            accuracy: pa('accuracy').asIntOrNull(),
            phases: pa('phases').letOrNull(
              (p) => (
                opening: p('opening').asIntOrNull(),
                middlegame: p('middlegame').asIntOrNull(),
                endgame: p('endgame').asIntOrNull(),
              ),
            ),
          ),
        ),
        black: it('black').letOrThrow(
          (pa) => PlayerAnalysis(
            inaccuracies: pa('inaccuracy').asIntOrThrow(),
            mistakes: pa('mistake').asIntOrThrow(),
            blunders: pa('blunder').asIntOrThrow(),
            acpl: pa('acpl').asIntOrNull(),
            accuracy: pa('accuracy').asIntOrNull(),
            phases: pa('phases').letOrNull(
              (p) => (
                opening: p('opening').asIntOrNull(),
                middlegame: p('middlegame').asIntOrNull(),
                endgame: p('endgame').asIntOrNull(),
              ),
            ),
          ),
        ),
      ),
    ),
    isAnalysisComplete: !isAnalysisIncomplete,
    division: pick(
      'division',
    ).letOrNull((it) => (middle: it('middle').asIntOrNull(), end: it('end').asIntOrNull())),
  );
}

String _nagToJugdmentName(int nag) => switch (nag) {
  6 => 'Inaccuracy',
  2 => 'Mistake',
  4 => 'Blunder',
  int() => '',
};

typedef ServerAnalysis = ({GameId id, PlayerAnalysis white, PlayerAnalysis black});

typedef GameDivision = ({int? middle, int? end});

@freezed
sealed class FenSocketEvent with _$FenSocketEvent {
  const factory FenSocketEvent({
    required GameId id,
    required String fen,
    required Move lastMove,
    required Duration whiteClock,
    required Duration blackClock,
  }) = _FenSocketEvent;

  factory FenSocketEvent.fromJson(Map<String, dynamic> json) {
    return _fenEventFromPick(pick(json).required());
  }
}

FenSocketEvent _fenEventFromPick(RequiredPick pick) {
  return FenSocketEvent(
    id: pick('id').asGameIdOrThrow(),
    fen: pick('fen').asStringOrThrow(),
    lastMove: pick('lm').asUciMoveOrThrow(),
    whiteClock: pick('wc').asDurationFromSecondsOrThrow(),
    blackClock: pick('bc').asDurationFromSecondsOrThrow(),
  );
}
