import 'package:chess/chess.dart' as ch;
import 'package:flutter/foundation.dart';

/// A resolved chess move plus the resulting position state.
@immutable
class ChessMove {
  const ChessMove({
    required this.san,
    required this.from,
    required this.to,
    this.promotion,
    required this.fenAfter,
    required this.uci,
  });

  final String san;
  final String from;
  final String to;
  final String? promotion;
  final String fenAfter;
  final String uci;

  @override
  String toString() => 'ChessMove($san $from$to => $fenAfter)';

  @override
  bool operator ==(Object other) =>
      other is ChessMove &&
      other.san == san &&
      other.from == from &&
      other.to == to &&
      other.promotion == promotion &&
      other.fenAfter == fenAfter &&
      other.uci == uci;

  @override
  int get hashCode => Object.hash(san, from, to, promotion, fenAfter, uci);
}

/// Resilient wrapper around the chess rules engine. All chess-package types
/// are confined here; the rest of the app deals with plain FEN/SAN/UCI strings.
class ChessService {
  const ChessService();

  /// Load a position from a FEN. Returns null if the FEN is invalid.
  ch.Chess? fromFen(String fen) {
    try {
      final chess = ch.Chess();
      if (!chess.load(fen, check_validity: true)) return null;
      return chess;
    } catch (_) {
      return null;
    }
  }

  static const String initialFen =
      'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

  /// The side to move in the current position.
  String turn(String fen) {
    final c = fromFen(fen);
    if (c == null) return 'w';
    return c.turn == ch.Color.WHITE ? 'w' : 'b';
  }

  /// Attempt to play the given SAN from [fen] and return the resulting move.
  /// Returns null when the SAN is illegal in that position.
  ChessMove? resolveSan(String fen, String san) {
    final c = fromFen(fen);
    if (c == null) return null;

    final targetSanClean = san.replaceAll(RegExp(r'[+#?!]+$'), '');
    final moves = c.generate_moves();
    for (final m in moves) {
      final mSan = c.move_to_san(m);
      final mSanClean = mSan.replaceAll(RegExp(r'[+#?!]+$'), '');
      if (mSanClean == targetSanClean || mSan == san) {
        c.make_move(m);
        final fenAfter = c.fen;
        c.undo_move();

        final promotion = m.promotion?.name;
        final uci = promotion != null ? '${m.fromAlgebraic}${m.toAlgebraic}$promotion' : '${m.fromAlgebraic}${m.toAlgebraic}';

        return ChessMove(
          san: mSan, // Return the canonical SAN with checks etc.
          from: m.fromAlgebraic,
          to: m.toAlgebraic,
          promotion: promotion,
          fenAfter: fenAfter,
          uci: uci,
        );
      }
    }
    return null;
  }

  /// All legal pseudo-SAN moves from [fen].
  List<String> legalMoves(String fen) {
    final c = fromFen(fen);
    if (c == null) return const [];
    return c.moves().cast<String>();
  }

  /// Apply a UCI move to [fen]; returns resulting FEN or null if illegal.
  String? applyUci(String fen, String uci) {
    final c = fromFen(fen);
    if (c == null) return null;
    if (uci.length < 4) return null;

    final from = uci.substring(0, 2);
    final to = uci.substring(2, 4);
    final promotion = uci.length > 4 ? uci.substring(4) : null;

    if (c.move({
          'from': from,
          'to': to,
          'promotion': ?promotion,
        })) {
      return c.fen;
    }
    return null;
  }

  /// The standard initial FEN.
  String get initialFenValue => initialFen;
}