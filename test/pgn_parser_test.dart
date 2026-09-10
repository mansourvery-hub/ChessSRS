import 'package:chess_repertoire_srs/chess/pgn_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = PgnParser();

  group('PgnParser', () {
    test('splits multiple games correctly', () {
      const pgn = '''
[Event "Game 1"]
[Site "Site 1"]

1. e4 e5 *

[Event "Game 2"]
[Site "Site 2"]

1. d4 d5 *
''';
      final games = parser.splitGames(pgn);
      expect(games, hasLength(2));
      expect(games[0].headers['Event'], 'Game 1');
      expect(games[0].movetext, '1. e4 e5 *');
      expect(games[1].headers['Event'], 'Game 2');
      expect(games[1].movetext, '1. d4 d5 *');
    });

    test('tokenizes simple movetext', () {
      const movetext = '1. e4 e5 {symmetrical} 2. Nf3 \$1 Nc6 *';
      final tokens = parser.tokenize(movetext);

      expect(tokens, hasLength(7));
      expect(tokens[0], isA<MoveToken>());
      expect((tokens[0] as MoveToken).san, 'e4');
      expect(tokens[1], isA<MoveToken>());
      expect((tokens[1] as MoveToken).san, 'e5');
      expect(tokens[2], isA<CommentToken>());
      expect((tokens[2] as CommentToken).comment, 'symmetrical');
      expect(tokens[3], isA<MoveToken>());
      expect((tokens[3] as MoveToken).san, 'Nf3');
      expect(tokens[4], isA<NagToken>());
      expect((tokens[4] as NagToken).value, 1);
      expect(tokens[5], isA<MoveToken>());
      expect((tokens[5] as MoveToken).san, 'Nc6');
      expect(tokens[6], isA<ResultToken>());
    });

    test('parses variations recursively', () {
      const movetext = '1. e4 e5 2. Nf3 (2. f4 exf4) 2... Nc6';
      final tokens = parser.tokenize(movetext);
      final tree = parser.parseTokens(tokens);

      // Root (empty san) -> children: [e4]
      expect(tree.children, hasLength(1));
      final e4 = tree.children.first;
      expect(e4.san, 'e4');

      // e4 -> children: [e5]
      expect(e4.children, hasLength(1));
      final e5 = e4.children.first;
      expect(e5.san, 'e5');

      // e5 -> children: [Nf3, f4] (Nf3 is mainline, f4 is variation sibling!)
      expect(e5.children, hasLength(2));
      expect(e5.children[0].san, 'Nf3');
      expect(e5.children[1].san, 'f4');

      // f4 variation continues to exf4
      final f4 = e5.children[1];
      expect(f4.children, hasLength(1));
      expect(f4.children.first.san, 'exf4');

      // Nf3 mainline continues to Nc6
      final nf3 = e5.children[0];
      expect(nf3.children, hasLength(1));
      expect(nf3.children.first.san, 'Nc6');
    });

    test('supports nested variations', () {
      const movetext = '1. e4 e5 (1... c5 2. Nf3 (2. c3 d5))';
      final tokens = parser.tokenize(movetext);
      final tree = parser.parseTokens(tokens);

      // The variation `1... c5` branches from the position after 1. e4, so it
      // is a sibling of 1... e5 under the e4 node, not a child of the root.
      expect(tree.children, hasLength(1));
      final e4 = tree.children.first;
      expect(e4.san, 'e4');
      expect(e4.children, hasLength(2));
      expect(e4.children[0].san, 'e5');
      expect(e4.children[1].san, 'c5');

      // c5 -> children: [Nf3, c3]
      final c5 = e4.children[1];
      expect(c5.children, hasLength(2));
      expect(c5.children[0].san, 'Nf3');
      expect(c5.children[1].san, 'c3');

      // Nested variation d5 attaches under c3.
      final c3 = c5.children[1];
      expect(c3.children, hasLength(1));
      expect(c3.children.first.san, 'd5');
    });

    test('tokenizes concatenated move numbers like 1.e4', () {
      const movetext = '1.e4 e5 2.Nf3 Nc6 3.Bb5 a6';
      final tokens = parser.tokenize(movetext);
      final sans = tokens.whereType<MoveToken>().map((t) => t.san).toList();
      expect(sans, ['e4', 'e5', 'Nf3', 'Nc6', 'Bb5', 'a6']);
    });

    test('preserves comments on correct moves', () {
      const movetext = '1. e4 {king pawn} e5 {open game}';
      final tokens = parser.tokenize(movetext);
      final tree = parser.parseTokens(tokens);

      final e4 = tree.children.first;
      expect(e4.san, 'e4');
      expect(e4.comment, 'king pawn');

      final e5 = e4.children.first;
      expect(e5.san, 'e5');
      expect(e5.comment, 'open game');
    });
  });
}