import 'package:chess_repertoire_srs/chess/chess_service.dart';
import 'package:chess_repertoire_srs/domain/entities/position_node.dart';
import 'package:chess_repertoire_srs/domain/entities/repertoire_move.dart';
import 'package:chess_repertoire_srs/domain/repertoire_decision.dart';
import 'package:chess_repertoire_srs/domain/srs/review_result.dart';
import 'package:chess_repertoire_srs/domain/srs/review_outcome.dart';
import 'package:chess_repertoire_srs/domain/srs/review_state.dart';
import 'package:chess_repertoire_srs/domain/srs/scheduler.dart';
import 'package:chess_repertoire_srs/persistence/study_repository.dart';
import 'package:chess_repertoire_srs/domain/clock.dart';

/// Application service that orchestrates the review process.
class ReviewService {
  ReviewService({
    required this.studyRepository,
    required this.chessService,
    required this.scheduler,
    required this.clock,
  });

  final StudyRepository studyRepository;
  final ChessService chessService;
  final Scheduler scheduler;
  final Clock clock;

  /// Get all due repertoire decisions, optionally scoped to a specific [studyId].
  Future<List<RepertoireDecision>> getDueDecisions({String? studyId}) async {
    final now = clock.now();
    final studies = studyId != null
        ? [await studyRepository.getStudy(studyId)]
        : await studyRepository.getAllStudies();

    final allDecisions = <RepertoireDecision>[];

    for (final study in studies) {
      if (study == null) continue;
      final chapters = await studyRepository.getChaptersByStudy(study.id);
      for (final chapter in chapters) {
        if (chapter.root != null) {
          _collectDueDecisions(chapter.root!, study.id, chapter.id, allDecisions);
        }
      }
    }

    final dueDecisions = <RepertoireDecision>[];
    for (final d in allDecisions) {
      final state = await studyRepository.getReviewState(d.id);
      if (state == null || state.isDueAt(now)) {
        dueDecisions.add(d);
      }
    }

    return dueDecisions;
  }

  void _collectDueDecisions(
    PositionNode node,
    String studyId,
    String chapterId,
    List<RepertoireDecision> list,
  ) {
    // Create decision at non-leaf positions with repertoire moves
    if (!node.isLeaf && node.childMoves.isNotEmpty) {
      final decision = RepertoireDecision.create(
        studyId: studyId,
        chapterId: chapterId,
        nodeId: node.id,
        expectedMoves: node.childMoves,
      );
      list.add(decision);
    }

    for (final child in node.children) {
      _collectDueDecisions(child, studyId, chapterId, list);
    }
  }

  /// Validate a submitted move against expected repertoire moves.
  Future<ReviewOutcome> validateMove(
    String decisionId,
    String from,
    String to,
    String? promotion,
  ) async {
    final decision = await studyRepository.getDecision(decisionId);
    if (decision == null) {
      return ReviewOutcome(correct: false);
    }

    final move = RepertoireMove(from: from, to: to, promotion: promotion);
    final correct = decision.accepts(move);

    return ReviewOutcome(
      correct: correct,
      expectedMove: correct ? move : decision.expectedMoves.firstOrNull,
    );
  }

  /// Process a review result and update SRS state.
  Future<ReviewState> processReviewResult(
    String decisionId,
    bool correct,
  ) async {
    final now = clock.now();
    final previousState = await studyRepository.getReviewState(decisionId) ??
        ReviewState.initial(itemId: decisionId, decisionId: decisionId);

    final reviewResult = correct
        ? const ReviewResult.correct()
        : const ReviewResult.incorrect();

    final newState = scheduler.schedule(
      previous: previousState,
      result: reviewResult,
      now: now,
    );

    await studyRepository.saveReviewState(newState);
    return newState;
  }

  /// Get the next node to display after a correct move.
  Future<PositionNode?> getNextNode(
    String decisionId,
    RepertoireMove move,
  ) async {
    final decision = await studyRepository.getDecision(decisionId);
    if (decision == null) return null;

    // Get the chapter to access the position tree
    final chapter = await studyRepository.getChapter(decision.chapterId);
    if (chapter == null || chapter.root == null) return null;

    // Find the node and get its child for the move
    final node = _findNodeById(chapter.root!, decision.nodeId);
    if (node == null) return null;

    return node.childForMove(move);
  }

  PositionNode? _findNodeById(PositionNode root, String targetId) {
    if (root.id == targetId) return root;
    for (final child in root.children) {
      final found = _findNodeById(child, targetId);
      if (found != null) return found;
    }
    return null;
  }
}