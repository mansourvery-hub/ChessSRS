import 'package:chess_repertoire_srs/chess/pgn_converter.dart';
import 'package:chess_repertoire_srs/chess/pgn_parser.dart';
import 'package:chess_repertoire_srs/domain/entities/chapter.dart';
import 'package:chess_repertoire_srs/domain/entities/study.dart';
import 'package:chess_repertoire_srs/domain/import_result.dart';

/// Orchestrates PGN import: splitting, parsing, and domain conversion.
class ImportService {
  const ImportService({required this.converter});

  final PgnConverter converter;

  ImportResult importPgn(String pgnText, {String studyTitle = 'Imported Study'}) {
    final parser = PgnParser();
    final games = parser.splitGames(pgnText);

    if (games.isEmpty) {
      return ImportResult(
        study: Study.empty,
        chapters: const [],
        errors: const [],
        warnings: const [],
      );
    }

    final study = Study.create(title: studyTitle);
    final chapters = <Chapter>[];
    final errors = <ImportError>[];

    for (var i = 0; i < games.length; i++) {
      final game = games[i];
      final headers = game.headers;
      final chapterTitle = headers['Event'] ?? headers['Site'] ?? 'Game $i';

      try {
        final startingFen = headers['FEN'];
        final stringErrors = <String>[];
        final root = converter.convertTree(
          parser.parseTokens(parser.tokenize(game.movetext)),
          study.id,
          chapterTitle,
          startingFen: startingFen,
          errors: stringErrors,
        );

        for (final err in stringErrors) {
          errors.add(ImportError(
            chapterTitle: chapterTitle,
            moveNumber: 0,
            message: err,
          ));
        }

        if (root != null) {
          final chapter = Chapter.create(
            studyId: study.id,
            sourceOrder: i,
            title: chapterTitle,
            startingFen: startingFen ?? converter.chess.initialFenValue,
            root: root,
          );
          chapters.add(chapter);
        }
      } catch (e) {
        errors.add(ImportError(
          chapterTitle: chapterTitle,
          moveNumber: 0,
          message: e.toString(),
        ));
      }
    }

    return ImportResult(study: study, chapters: chapters, errors: errors, warnings: const []);
  }
}