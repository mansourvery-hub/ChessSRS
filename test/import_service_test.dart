import 'package:chess_repertoire_srs/chess/chess_service.dart';
import 'package:chess_repertoire_srs/chess/pgn_converter.dart';
import 'package:chess_repertoire_srs/import/import_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const chess = ChessService();
  const converter = PgnConverter(chess: chess);
  const importer = ImportService(converter: converter);

  group('ImportService', () {
    test('imports single game PGN into a Study with Chapter and PositionNodes', () {
      const pgn = '''
[Event "Italian Game"]
[Site "Chess Study"]

1. e4 e5 2. Nf3 Nc6 3. Bc4 Bc5 *
''';

      final result = importer.importPgn(pgn, studyTitle: 'My Repertoire');

      expect(result.hasErrors, isFalse);
      expect(result.study.title, 'My Repertoire');
      expect(result.chapters, hasLength(1));

      final chapter = result.chapters.first;
      expect(chapter.title, 'Italian Game');
      expect(chapter.root, isNotNull);

      // Root has child e4
      final root = chapter.root!;
      expect(root.children, hasLength(1));
      final e4 = root.children.first;
      expect(e4.incomingMove?.san, 'e4');

      // e4 -> e5 -> Nf3 -> Nc6 -> Bc4 -> Bc5
      final e5 = e4.children.first;
      expect(e5.incomingMove?.san, 'e5');
      final nf3 = e5.children.first;
      expect(nf3.incomingMove?.san, 'Nf3');
      final nc6 = nf3.children.first;
      expect(nc6.incomingMove?.san, 'Nc6');
    });

    test('imports variations as branches under the same position node', () {
      const pgn = '''
[Event "Sicilian Variations"]

1. e4 c5 2. Nf3 (2. c3 d5 3. exd5 Qxd5) 2... d6 *
''';

      final result = importer.importPgn(pgn);
      expect(result.hasErrors, isFalse);
      expect(result.chapters, hasLength(1));

      final chapter = result.chapters.first;
      final c5 = chapter.root!.children.first.children.first;
      expect(c5.incomingMove?.san, 'c5');

      // Under c5, there are two choices for White: 2. Nf3 and 2. c3
      expect(c5.children, hasLength(2));
      final moves = c5.children.map((n) => n.incomingMove?.san).toList();
      expect(moves, containsAll(['Nf3', 'c3']));
    });

    test('imports multiple chapters from one multi-game PGN', () {
      const pgn = '''
[Event "Chapter 1: King Pawn"]
1. e4 e5 *

[Event "Chapter 2: Queen Pawn"]
1. d4 d5 *
''';

      final result = importer.importPgn(pgn);
      expect(result.hasErrors, isFalse);
      expect(result.chapters, hasLength(2));
      expect(result.chapters[0].title, 'Chapter 1: King Pawn');
      expect(result.chapters[1].title, 'Chapter 2: Queen Pawn');
      expect(result.chapters[0].sourceOrder, 0);
      expect(result.chapters[1].sourceOrder, 1);
    });

    test('gracefully reports invalid moves without crashing', () {
      const pgn = '''
[Event "Corrupt Move"]
1. e4 e5 2. Ke99 *
''';

      final result = importer.importPgn(pgn);
      expect(result.hasErrors, isTrue);
      expect(result.errors.first.message, contains('Illegal SAN move'));
    });
  });
}