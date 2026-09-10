import 'package:chess_repertoire_srs/domain/entities/chapter.dart';
import 'package:chess_repertoire_srs/domain/entities/position_node.dart';
import 'package:chess_repertoire_srs/domain/entities/study.dart';
import 'package:chess_repertoire_srs/domain/repertoire_decision.dart';
import 'package:chess_repertoire_srs/domain/srs/review_event.dart';
import 'package:chess_repertoire_srs/domain/srs/review_state.dart';

/// Interface for persisting study data.
abstract class StudyRepository {
  Future<Study> createStudy(String title);
  Future<Study?> getStudy(String id);
  Future<List<Study>> getAllStudies();
  Future<void> saveStudy(Study study);
  Future<void> deleteStudy(String id);

  Future<Chapter> createChapter({
    required String studyId,
    required int sourceOrder,
    String? title,
    String? startingFen,
  });
  Future<Chapter?> getChapter(String id);
  Future<List<Chapter>> getChaptersByStudy(String studyId);
  Future<void> saveChapter(Chapter chapter);
  Future<void> savePositionTree(String chapterId, PositionNode root);
  Future<PositionNode?> getPositionTree(String chapterId);
  Future<RepertoireDecision?> getDecision(String id);
  Future<List<RepertoireDecision>> getDecisionsByChapter(String chapterId);
  Future<void> saveDecision(RepertoireDecision decision);
  Future<List<RepertoireDecision>> getDecisionsDue();
  Future<ReviewState?> getReviewState(String decisionId);
  Future<void> saveReviewState(ReviewState state);
  Future<List<ReviewEvent>> getReviewEvents(String decisionId);
  Future<void> saveReviewEvent(ReviewEvent event);
}