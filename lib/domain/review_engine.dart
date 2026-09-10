import 'package:chess_repertoire_srs/chess/chess_service.dart';
import 'package:chess_repertoire_srs/domain/repertoire_decision.dart';
import 'package:chess_repertoire_srs/domain/entities/repertoire_move.dart';
import 'package:chess_repertoire_srs/domain/srs/scheduler.dart';
import 'package:chess_repertoire_srs/domain/srs/review_state.dart';
import 'package:chess_repertoire_srs/domain/entities/chapter.dart';
import 'package:chess_repertoire_srs/domain/entities/position_node.dart';
import 'package:chess_repertoire_srs/domain/clock.dart';

/// The next review prompt: a position with expected repertoire moves.
class ReviewPrompt {
  const ReviewPrompt({
    required this.positionFen,
    required this.expectedMoves,
    required this.decisionId,
    required this.nodeId,
    required this.sideToMove,
    this.currentMoveNumber,
  });

  final String positionFen;
  final List<RepertoireMove> expectedMoves;
  final String decisionId;
  final String nodeId;
  final String sideToMove;
  final int? currentMoveNumber;
}

/// The outcome of a review step: whether the answer was correct and any feedback.
class ReviewOutcome {
  const ReviewOutcome({
    required this.correct,
    this.expectedMove,
  });

  final bool correct;
  final RepertoireMove? expectedMove;
}

/// Main review orchestration engine.
class ReviewEngine {
  ReviewEngine({
    required this.chess,
    required this.scheduler,
    required this.clock,
  });

  final ChessService chess;
  final Scheduler scheduler;
  final Clock clock;

  /// Determine all due decisions for a given scope.
  List<RepertoireDecision> getDueDecisions(List<Chapter> chapters) {
    final decisions = <RepertoireDecision>[];

    for (final chapter in chapters) {
      if (chapter.root == null) continue;
      _collectDecisions(chapter.root!, decisions);
    }

    return decisions;
  }

  void _collectDecisions(PositionNode node, List<RepertoireDecision> list) {
    // Only create a decision at positions where it's the user's turn and there
    // are children to choose from. For MVP we assume the user's side is white
    // (orientation can be extended later).
    final sideToMove = chess.turn(node.fen);

    // If this is the root (no incoming move), it's the first move. Usually
    // this is a user-side move (white to move), but could be black if the
    // chapter starts with a black-to-move position.
    if (node.incomingMove != null || sideToMove == 'w') {
      if (!node.isLeaf) {
        final decision = RepertoireDecision.create(
          studyId: '', // Will be set by caller
          chapterId: '', // Will be set by caller
          nodeId: node.id,
          expectedMoves: node.childMoves,
        );
        list.add(decision);
      }
    }

    for (final child in node.children) {
      _collectDecisions(child, list);
    }
  }

  /// Convert due decisions into a map keyed by nodeId for fast lookup.
  Map<String, RepertoireDecision> decisionsByNode(
    List<RepertoireDecision> decisions,
  ) {
    final map = <String, RepertoireDecision>{};
    for (final d in decisions) {
      map[d.nodeId] = d;
    }
    return map;
  }

  /// Build the first review prompt from the current position.
  ReviewPrompt buildPrompt(PositionNode node) {
    return ReviewPrompt(
      positionFen: node.fen,
      expectedMoves: node.childMoves,
      decisionId: '', // Caller will set
      nodeId: node.id,
      sideToMove: chess.turn(node.fen),
      currentMoveNumber: null, // Derived from node depth
    );
  }

  /// Validate a move against the node's expected repertoire moves.
  ReviewOutcome validateMove(PositionNode node, String from, String to, String? promotion) {
    final move = RepertoireMove(from: from, to: to, promotion: promotion);
    for (final expected in node.childMoves) {
      if (expected.from == from && expected.to == to && expected.promotion == promotion) {
        return ReviewOutcome(correct: true, expectedMove: move);
      }
    }
    return const ReviewOutcome(correct: false);
  }

  /// Apply a correct move and compute the next review state.
  ReviewState applyMoveAndAdvance(
    PositionNode node,
    RepertoireMove move,
    ReviewState previousState,
  ) {
    // The move leads to a child node - find it
    final child = node.childForMove(move);
    if (child == null) {
      return previousState;
    }

    // Determine if this child node is a due decision
    if (!child.isLeaf) {
      // If the next node is a decision point and due, return it as the next prompt
      // This is handled by the caller which will fetch the next due decision.
    }

    return previousState;
  }

  /// Get the next node to display after a correct answer.
  PositionNode nextNodeAfter(PositionNode currentNode, RepertoireMove move) {
    return currentNode.childForMove(move) ?? currentNode;
  }
}