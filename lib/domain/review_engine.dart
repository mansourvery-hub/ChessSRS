import 'package:chess_repertoire_srs/chess/chess_service.dart';
import 'package:chess_repertoire_srs/domain/repertoire_decision.dart';
import 'package:chess_repertoire_srs/domain/entities/chapter.dart';
import 'package:chess_repertoire_srs/domain/entities/position_node.dart';
import 'package:chess_repertoire_srs/domain/entities/repertoire_move.dart';
import 'package:chess_repertoire_srs/domain/srs/review_result.dart';
import 'package:chess_repertoire_srs/domain/srs/review_outcome.dart';
import 'package:chess_repertoire_srs/domain/srs/review_state.dart';
import 'package:chess_repertoire_srs/domain/srs/scheduler.dart';
import 'package:chess_repertoire_srs/domain/clock.dart';

export 'package:chess_repertoire_srs/domain/srs/review_outcome.dart';

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

/// What happens after a review answer.
class ReviewContinuation {
  const ReviewContinuation({
    required this.nextPrompt,
    this.autoPlayedMoves = const [],
  });

  /// The next prompt to show (null if review session ends).
  final ReviewPrompt? nextPrompt;

  /// Moves that were automatically played during continuation.
  final List<AutoPlayedMove> autoPlayedMoves;
}

/// A move that was automatically played during continuation.
class AutoPlayedMove {
  const AutoPlayedMove({
    required this.from,
    required this.to,
    this.promotion,
    required this.san,
    required this.isUserMove,
  });

  final String from;
  final String to;
  final String? promotion;
  final String san;
  final bool isUserMove; // true if it was the user's move, false if opponent's
}

/// Result of a review step.
class ReviewStepResult {
  const ReviewStepResult({
    required this.outcome,
    required this.newState,
    this.continuation,
  });

  final ReviewOutcome outcome;
  final ReviewState newState;
  final ReviewContinuation? continuation;
}

/// Main review orchestration engine with proper state machine.
class ReviewEngine {
  ReviewEngine({
    required this.chess,
    required this.scheduler,
    required this.clock,
  });

  final ChessService chess;
  final Scheduler scheduler;
  final Clock clock;

  // Provider for review state (set by ReviewService)
  Future<ReviewState?> Function(String) _getReviewState = (id) async => null;
  Future<void> Function(String, ReviewState) _saveReviewState = (id, state) async {};

  void setReviewStateProvider(Future<ReviewState?> Function(String) provider) {
    _getReviewState = provider;
  }

  void setReviewStateSaver(Future<void> Function(String, ReviewState) saver) {
    _saveReviewState = saver;
  }

  Future<List<RepertoireDecision>> getDueDecisions(
    List<Chapter> chapters, {
    DateTime? now,
  }) async {
    final decisions = <RepertoireDecision>[];
    final currentTime = now ?? clock.now();

    for (final chapter in chapters) {
      if (chapter.root == null) continue;
      _collectDecisions(chapter.root!, decisions, chapterId: chapter.id, studyId: '');
    }

    // Filter to only due decisions
    final dueDecisions = <RepertoireDecision>[];
    for (final decision in decisions) {
      final state = await _getReviewState(decision.id);
      if (state == null || state.isDueAt(currentTime)) {
        dueDecisions.add(decision);
      }
    }

    return dueDecisions;
  }

  void _collectDecisions(PositionNode node, List<RepertoireDecision> list,
      {required String chapterId, required String studyId}) {
    // Only create a decision at positions where it's the user's turn and there
    // are children to choose from.
    // For MVP we assume the user's side is white (orientation can be extended later).
    final sideToMove = chess.turn(node.fen);

    // If this is the root (no incoming move), it's the first move.
    // This is typically a user-side move (white to move), but could be black
    // if the chapter starts with a black-to-move position.
    final isUserTurn = node.incomingMove != null || sideToMove == 'w';

    if (isUserTurn && !node.isLeaf && node.childMoves.isNotEmpty) {
      final decision = RepertoireDecision.create(
        studyId: studyId,
        chapterId: chapterId,
        nodeId: node.id,
        expectedMoves: node.childMoves,
      );
      list.add(decision);
    }

    for (final child in node.children) {
      _collectDecisions(child, list, chapterId: chapterId, studyId: studyId);
    }
  }

  /// Build the first review prompt from the current position.
  ReviewPrompt buildPrompt(PositionNode node, {required String decisionId}) {
    return ReviewPrompt(
      positionFen: node.fen,
      expectedMoves: node.childMoves,
      decisionId: decisionId,
      nodeId: node.id,
      sideToMove: chess.turn(node.fen),
      currentMoveNumber: null,
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
    return ReviewOutcome(correct: false, expectedMove: node.childMoves.firstOrNull);
  }

  /// Process a review answer and return the next step.
  Future<ReviewStepResult> processAnswer({
    required PositionNode currentNode,
    required RepertoireDecision decision,
    required String from,
    required String to,
    required String? promotion,
    required ReviewState previousState,
  }) async {
    final now = clock.now();
    final move = RepertoireMove(from: from, to: to, promotion: promotion);
    final isCorrect = decision.accepts(move);

    // Update SRS state
    final reviewResult = isCorrect
        ? const ReviewResult.correct()
        : const ReviewResult.incorrect();

    final newState = scheduler.schedule(
      previous: previousState,
      result: ReviewResult(correct: isCorrect),
      now: clock.now(),
    );

    await _saveReviewState(decision.id, newState);

    ReviewContinuation? continuation;

    if (isCorrect) {
      // Correct answer: advance and auto-continue through non-due positions
      final continuation = await _advanceAndContinue(
        currentNode: currentNode,
        move: move,
        decision: decision,
      );
      return ReviewStepResult(
        outcome: ReviewOutcome(correct: true, expectedMove: move),
        newState: newState,
        continuation: continuation,
      );
    } else {
      // Incorrect answer: reveal expected move, record failure
      final expectedMove = decision.expectedMoves.firstOrNull;
      return ReviewStepResult(
        outcome: ReviewOutcome(correct: false, expectedMove: expectedMove),
        newState: newState,
        continuation: null, // UI should show feedback, then continue
      );
    }
  }

  /// Advance after a correct answer and auto-continue through non-due positions.
  Future<ReviewContinuation> _advanceAndContinue({
    required PositionNode currentNode,
    required RepertoireMove move,
    required RepertoireDecision decision,
  }) async {
    final autoPlayedMoves = <AutoPlayedMove>[];
    var currentNodeAfterMove = currentNode.childForMove(move);

    // If the move leads to a child, we're now at the opponent's position
    while (currentNodeAfterMove != null) {
      // Check if this node has a due decision
      final isUserTurn = _isUserTurn(currentNodeAfterMove);
      final hasDueDecision = isUserTurn && 
          !currentNodeAfterMove.isLeaf && 
          currentNodeAfterMove.childMoves.isNotEmpty;

      if (hasDueDecision) {
        // Check if this decision is due
        final decision = RepertoireDecision.create(
          studyId: '',
          chapterId: '',
          nodeId: currentNodeAfterMove.id,
          expectedMoves: currentNodeAfterMove.childMoves,
        );
        final state = await _getReviewState(decision.id);
        final now = clock.now();
        
        if (state == null || state.isDueAt(now)) {
          // This is a due decision - stop here and show prompt
          final prompt = ReviewPrompt(
            positionFen: currentNodeAfterMove.fen,
            expectedMoves: currentNodeAfterMove.childMoves,
            decisionId: decision.id,
            nodeId: currentNodeAfterMove.id,
            sideToMove: chess.turn(currentNodeAfterMove.fen),
          );
          return ReviewContinuation(nextPrompt: prompt, autoPlayedMoves: autoPlayedMoves);
        }
      }

      // Not a due decision point - auto-continue
      if (!currentNodeAfterMove.isLeaf) {
        // Auto-play the next move
        RepertoireMove nextMove;
        final sideToMove = chess.turn(currentNodeAfterMove.fen);
        final isUserTurn = sideToMove == 'w'; // Assuming white is user for now

        if (isUserTurn) {
          // User's turn but not due - play the first repertoire move
          final bestMove = currentNodeAfterMove.childMoves.first;
          autoPlayedMoves.add(AutoPlayedMove(
            from: bestMove.from,
            to: bestMove.to,
            promotion: bestMove.promotion,
            san: bestMove.san,
            isUserMove: true,
          ));
          currentNodeAfterMove = currentNodeAfterMove.childForMove(bestMove)!;
        } else {
          // Opponent's turn - auto-play their move (first child)
          final opponentMove = currentNodeAfterMove.childMoves.first;
          autoPlayedMoves.add(AutoPlayedMove(
            from: opponentMove.from,
            to: opponentMove.to,
            promotion: opponentMove.promotion,
            san: opponentMove.san,
            isUserMove: false,
          ));
          currentNodeAfterMove = currentNodeAfterMove.childForMove(opponentMove)!;
        }
      } else {
        // End of line - no more moves
        break;
      }
    }

    return const ReviewContinuation(nextPrompt: null, autoPlayedMoves: []);
  }

  bool _isUserTurn(PositionNode node) {
    final sideToMove = chess.turn(node.fen);
    return sideToMove == 'w'; // Assuming white is user for MVP
  }
}