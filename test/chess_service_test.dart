import 'package:chess_repertoire_srs/chess/chess_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const chess = ChessService();

  group('ChessService', () {
    test('resolves SAN moves to coordinates', () {
      final move = chess.resolveSan(
        ChessService.initialFen,
        'e4',
      );
      expect(move, isNotNull);
      expect(move!.from, 'e2');
      expect(move.to, 'e4');
      expect(move.uci, 'e2e4');
    });

    test('resolves castling', () {
      // Start from a FEN where white can castle kingside soon.
      // 1.e4 e5 2.Nf3 Nc6 3.Bc4 Bc5 4.O-O
      const sequence = ['e4', 'e5', 'Nf3', 'Nc6', 'Bc4', 'Bc5'];
      var fen = ChessService.initialFen;
      for (final san in sequence) {
        final m = chess.resolveSan(fen, san);
        expect(m, isNotNull, reason: 'move $san');
        fen = m!.fenAfter;
      }
      final castle = chess.resolveSan(fen, 'O-O');
      expect(castle, isNotNull);
      expect(castle!.from, 'e1');
      expect(castle.to, 'g1');
    });

    test('en passant works', () {
      // 1.e4 (any) ... then black plays ...c5 2.e5 d5 -> white exd6 e.p.
      final moves = chess.resolveSan(ChessService.initialFen, 'e4')!;
      var fen = moves.fenAfter;
      fen = chess.resolveSan(fen, 'c5')!.fenAfter;
      fen = chess.resolveSan(fen, 'e5')!.fenAfter;
      fen = chess.resolveSan(fen, 'd5')!.fenAfter;
      final ep = chess.resolveSan(fen, 'exd6');
      expect(ep, isNotNull);
      expect(ep!.from, 'e5');
      expect(ep.to, 'd6');
    });

    test('promotion resolves', () {
      // White pawn on e7, black king well away on h8.
      const fen = '7k/4P3/8/8/8/8/8/4K3 w - - 0 1';
      final m = chess.resolveSan(fen, 'e8=Q');
      expect(m, isNotNull);
      expect(m!.to, 'e8');
      expect(m.promotion, 'q');
    });

    test('rejects illegalk move with null', () {
      expect(chess.resolveSan(ChessService.initialFen, 'Qd1h5'), isNull);
    });

    test('legalMoves returns SAN list', () {
      final moves = chess.legalMoves(ChessService.initialFen);
      expect(moves, contains('e4'));
      expect(moves, contains('d4'));
      expect(moves, contains('Nf3'));
    });

    test('applyUci returns next FEN', () {
      final next = chess.applyUci(ChessService.initialFen, 'e2e4');
      expect(next, isNotNull);
      expect(next!, startsWith('rnbqkbnr/pppppppp/8/8/4P3'));
    });
  });
}