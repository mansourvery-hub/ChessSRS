// Copyright (C) 2024 ChessSRS contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:chess_srs/src/domain/chapter.dart';
import 'package:chess_srs/src/domain/repertoire_decision.dart';
import 'package:chess_srs/src/domain/repertoire_move.dart';
import 'package:chess_srs/src/domain/repertoire_node.dart';
import 'package:chess_srs/src/domain/study.dart';
import 'package:dartchess/dartchess.dart';

/// Structured error produced during PGN import.
///
/// Contains enough context (chapter title + move index) to let the user
/// locate the offending move (QUALITY.md §3.1: Graceful Degradation).
class ImportError {
  const ImportError({required this.chapterTitle, required this.moveIndex, required this.message});

  /// Chapter (game) in which the error occurred.
  final String chapterTitle;

  /// 0-based index of the move in the game that triggered the error.
  /// -1 means the error applies to the whole chapter (e.g. bad FEN header).
  final int moveIndex;

  /// Human-readable description of the error.
  final String message;

  @override
  String toString() =>
      'ImportError(chapter: "$chapterTitle", moveIndex: $moveIndex, message: "$message")';
}

/// Complete result of a PGN import operation.
class ImportResult {
  const ImportResult({
    required this.study,
    required this.chapters,
    required this.decisions,
    required this.errors,
  });

  /// The created [Study] container.
  final Study study;

  /// Successfully imported chapters (one per PGN game).
  final List<Chapter> chapters;

  /// All [RepertoireDecision]s derived from the imported chapters.
  final List<RepertoireDecision> decisions;

  /// Structured errors encountered during import.
  /// Non-empty means some chapters or moves were skipped or quarantined.
  final List<ImportError> errors;

  bool get hasErrors => errors.isNotEmpty;
  bool get isEmpty => chapters.isEmpty;

  @override
  String toString() =>
      'ImportResult(chapters: ${chapters.length}, decisions: ${decisions.length}, '
      'errors: ${errors.length})';
}

/// Derives a 4-field FEN position key from a full 6-field FEN.
///
/// The key is: `<placement> <turn> <castling> <ep>`
/// (QUALITY.md §2.3: Position Identity Integrity).
String fenKey(String fullFen) {
  final parts = fullFen.split(' ');
  if (parts.length < 4) return fullFen; // malformed — return as-is
  return '${parts[0]} ${parts[1]} ${parts[2]} ${parts[3]}';
}

/// Converts a dartchess [NormalMove] and [Position] into a domain [RepertoireMove].
RepertoireMove normalmoveToRepertoireMove(NormalMove move, Position position) {
  final (_, san) = position.makeSan(move);
  return RepertoireMove(
    from: move.from.name,
    to: move.to.name,
    promotion: move.promotion?.letter,
    san: san,
  );
}

/// Imports a multi-game PGN string into a [Study] with [Chapter]s and [RepertoireDecision]s.
///
/// The [repertoireSide] is the [Side] whose moves become [RepertoireDecision]s.
/// Opponent moves are recorded in the tree but not scheduled.
/// When [repertoireSide] is null, every node with at least one continuation
/// becomes a decision (useful for training both sides).
///
/// Errors are collected rather than thrown. A chapter with a fatal error
/// (e.g. bad starting FEN) is omitted from [ImportResult.chapters]; a
/// chapter with recoverable move errors is included with a truncated tree.
ImportResult importPgn(
  String pgnText, {
  String studyTitle = 'Imported Study',
  Side? repertoireSide,
}) {
  final List<PgnGame<PgnNodeData>> games;
  try {
    games = PgnGame.parseMultiGamePgn(pgnText);
  } catch (e) {
    // Catastrophic parse failure — return an empty result with one error.
    final study = Study.create(title: studyTitle);
    return ImportResult(
      study: study,
      chapters: const [],
      decisions: const [],
      errors: [ImportError(chapterTitle: studyTitle, moveIndex: -1, message: e.toString())],
    );
  }

  if (games.isEmpty) {
    final study = Study.create(title: studyTitle);
    return ImportResult(study: study, chapters: const [], decisions: const [], errors: const []);
  }

  final study = Study.create(title: studyTitle);
  final chapters = <Chapter>[];
  final decisions = <RepertoireDecision>[];
  final errors = <ImportError>[];

  for (var i = 0; i < games.length; i++) {
    final game = games[i];
    final headers = game.headers;

    // Derive a human-readable chapter title from PGN headers.
    final chapterTitle = _chapterTitle(headers, i);

    // Resolve starting position.
    Position startPosition;
    String startingFen;
    try {
      startPosition = PgnGame.startingPosition(headers);
      startingFen = startPosition.fen;
    } catch (e) {
      errors.add(
        ImportError(
          chapterTitle: chapterTitle,
          moveIndex: -1,
          message: 'Invalid starting position: $e',
        ),
      );
      continue; // skip this chapter
    }

    // Build the RepertoireNode tree, collecting any per-move errors.
    final chapterErrors = <ImportError>[];
    final root = _buildRoot(game.moves, startPosition, startingFen, chapterTitle, chapterErrors);

    errors.addAll(chapterErrors);

    final opening = extractOpeningFamily(headers);

    final chapter = Chapter.create(
      studyId: study.id,
      sourceOrder: i,
      title: chapterTitle,
      startingFen: headers.containsKey('FEN') ? startingFen : null,
      root: root,
      opening: opening,
    );
    chapters.add(chapter);

    // Derive decisions for this chapter.
    if (root != null) {
      _deriveDecisions(root, study.id, chapter.id, startPosition.turn, repertoireSide, decisions);
    }
  }

  return ImportResult(study: study, chapters: chapters, decisions: decisions, errors: errors);
}

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

String _chapterTitle(PgnHeaders headers, int index) {
  // Prefer a meaningful player matchup, but only when both names are real.
  final white = headers['White'];
  final black = headers['Black'];
  final playersReal = white != null && black != null && white != '?' && black != '?';
  if (playersReal) return '$white vs $black';

  // Fall back to Event or Site.
  for (final key in ['Event', 'Site']) {
    final v = headers[key];
    if (v != null && v.trim().isNotEmpty && v != '?') return v.trim();
  }

  return 'Game ${index + 1}';
}

/// Builds a [RepertoireNode] root from the PGN node tree, or null on fatal error.
RepertoireNode? _buildRoot(
  PgnNode<PgnNodeData> pgnRoot,
  Position startPosition,
  String startingFen,
  String chapterTitle,
  List<ImportError> errors,
) {
  final root = RepertoireNode.root(fen: startingFen, fenKey: fenKey(startingFen));

  // If there are no moves, return the empty root (a chapter can be a position study).
  if (pgnRoot.children.isEmpty) return root;

  final result = _buildChildren(pgnRoot, root, startPosition, chapterTitle, errors, 0);
  return result;
}

/// Recursively builds children from a [PgnNode], returning the updated parent.
RepertoireNode _buildChildren(
  PgnNode<PgnNodeData> pgnNode,
  RepertoireNode parent,
  Position position,
  String chapterTitle,
  List<ImportError> errors,
  int moveIndex,
) {
  var current = parent;

  for (final pgnChild in pgnNode.children) {
    final data = pgnChild.data;
    final san = data.san;

    // Parse the SAN move against the current position.
    final Move? parsed;
    try {
      parsed = position.parseSan(san);
    } catch (e) {
      errors.add(
        ImportError(
          chapterTitle: chapterTitle,
          moveIndex: moveIndex,
          message: 'Could not parse move "$san": $e',
        ),
      );
      continue;
    }

    if (parsed == null) {
      errors.add(
        ImportError(
          chapterTitle: chapterTitle,
          moveIndex: moveIndex,
          message: 'Illegal or unrecognized move "$san" at position ${position.fen}',
        ),
      );
      continue;
    }

    if (parsed is! NormalMove) {
      // Drop moves are not part of opening repertoires; skip silently.
      continue;
    }

    final reperMove = normalmoveToRepertoireMove(parsed, position);
    final nextPosition = position.play(parsed);
    final nextFen = nextPosition.fen;

    // Extract comment (prefer post-move comment, fall back to starting comment).
    final comment = data.comments?.join(' ').trim().isNotEmpty == true
        ? data.comments!.join(' ').trim()
        : data.startingComments?.join(' ').trim();

    var childNode = RepertoireNode.child(
      fen: nextFen,
      fenKey: fenKey(nextFen),
      incomingMove: reperMove,
      comment: comment?.isNotEmpty == true ? comment : null,
    );

    // Recurse into this child's subtree.
    childNode = _buildChildren(
      pgnChild,
      childNode,
      nextPosition,
      chapterTitle,
      errors,
      moveIndex + 1,
    );

    current = current.addChild(childNode);
  }

  return current;
}

/// Derives [RepertoireDecision]s from a position tree.
///
/// A decision is created at any node where:
/// - The side to move matches [repertoireSide] (or [repertoireSide] is null), AND
/// - The node has at least one child (there is a move to recall).
void _deriveDecisions(
  RepertoireNode node,
  String studyId,
  String chapterId,
  Side nodeSideToMove,
  Side? repertoireSide,
  List<RepertoireDecision> out,
) {
  if (node.children.isNotEmpty) {
    final isRepertoireSide = repertoireSide == null || nodeSideToMove == repertoireSide;

    if (isRepertoireSide) {
      out.add(
        RepertoireDecision.create(
          studyId: studyId,
          chapterId: chapterId,
          nodeId: node.id,
          expectedMoves: node.childMoves,
        ),
      );
    }

    // Recurse into children, flipping the side to move.
    final nextSide = nodeSideToMove == Side.white ? Side.black : Side.white;
    for (final child in node.children) {
      _deriveDecisions(child, studyId, chapterId, nextSide, repertoireSide, out);
    }
  }
}

/// Automatically extracts a normalized opening family name from PGN headers.
String? extractOpeningFamily(PgnHeaders headers) {
  // 1. Direct Opening header (e.g. "Sicilian Defense: Najdorf Variation")
  final opening = headers['Opening'];
  if (opening != null && opening.trim().isNotEmpty && opening != '?') {
    return _simplifyOpeningName(opening.trim());
  }

  // 2. Check Event header (e.g. "Sicilian Defense", "French Defence - Winawer")
  final event = headers['Event'];
  if (event != null && event.trim().isNotEmpty && event != '?' && !event.startsWith('Game ')) {
    final simplified = _simplifyOpeningName(event.trim());
    if (_isLikelyOpeningName(simplified)) {
      return simplified;
    }
  }

  // 3. Fallback: ECO code classification (standard FIDE/ChessBase ECO families)
  final eco = headers['ECO'];
  if (eco != null && eco.trim().isNotEmpty && eco != '?') {
    return _ecoToOpeningFamily(eco.trim().toUpperCase());
  }

  return null;
}

String _simplifyOpeningName(String raw) {
  final splitColon = raw.split(RegExp('[:,-]'));
  if (splitColon.isNotEmpty && splitColon.first.trim().isNotEmpty) {
    return splitColon.first.trim();
  }
  return raw.trim();
}

bool _isLikelyOpeningName(String name) {
  final lower = name.toLowerCase();
  const keywords = [
    'defense',
    'defence',
    'game',
    'gambit',
    'opening',
    'attack',
    'system',
    'sicilian',
    'french',
    'caro-kann',
    'caro',
    'ruy lopez',
    'italian',
    'scotch',
    "king's indian",
    'kings indian',
    "queen's indian",
    'queens indian',
    'nimzo',
    'gruenfeld',
    'grunfeld',
    'dutch',
    'english',
    'reti',
    'slav',
    'london',
    'catalan',
    'scandinavian',
    'pirc',
    'modern',
    'alekhine',
    'vienna',
  ];
  return keywords.any((k) => lower.contains(k));
}

String? _ecoToOpeningFamily(String eco) {
  if (eco.length < 2) return null;
  final letter = eco[0];
  final number = int.tryParse(eco.substring(1, 3)) ?? -1;
  if (number < 0) return null;

  if (letter == 'B') {
    if (number >= 20 && number <= 99) return 'Sicilian Defense';
    if (number >= 10 && number <= 19) return 'Caro-Kann Defense';
    if (number >= 0 && number <= 9) return 'Scandinavian / Alekhine';
  } else if (letter == 'C') {
    if (number >= 0 && number <= 19) return 'French Defense';
    if (number >= 20 && number <= 59) return 'Open Game';
    if (number >= 60 && number <= 99) return 'Ruy Lopez';
  } else if (letter == 'D') {
    if (number >= 10 && number <= 19) return 'Slav Defense';
    if (number >= 0 && number <= 69) return "Queen's Gambit";
    if (number >= 70 && number <= 99) return 'Grünfeld Defense';
  } else if (letter == 'E') {
    if (number >= 20 && number <= 59) return 'Nimzo-Indian Defense';
    if (number >= 60 && number <= 99) return "King's Indian Defense";
    if (number >= 0 && number <= 9) return 'Catalan Opening';
  } else if (letter == 'A') {
    if (number >= 10 && number <= 39) return 'English Opening';
    if (number >= 40 && number <= 44) return "Queen's Pawn Game";
    if (number >= 80 && number <= 99) return 'Dutch Defense';
  }
  return null;
}
