import 'package:chess_repertoire_srs/domain/entities/chapter.dart';
import 'package:chess_repertoire_srs/domain/entities/position_node.dart';
import 'package:chess_repertoire_srs/domain/entities/study.dart';
import 'package:chess_repertoire_srs/domain/repertoire_decision.dart';
import 'package:chess_repertoire_srs/domain/srs/review_state.dart';
import 'package:chess_repertoire_srs/domain/srs/review_event.dart';
import 'package:chess_repertoire_srs/persistence/study_repository.dart';

/// In-memory implementation of StudyRepository for MVP.
class InMemoryStudyRepository implements StudyRepository {
  final Map<String, Study> _studies = {};
  final Map<String, Chapter> _chapters = {};
  final Map<String, PositionNode> _positionTrees = {};
  final Map<String, RepertoireDecision> _decisions = {};
  final Map<String, ReviewState> _reviewStates = {};
  final Map<String, List<ReviewEvent>> _reviewEvents = {};

  @override
  Future<Study> createStudy(String title) async {
    final study = Study.create(title: title);
    _studies[study.id] = study;
    return study;
  }

  @override
  Future<Study?> getStudy(String id) async {
    return _studies[id];
  }

  @override
  Future<List<Study>> getAllStudies() async {
    return _studies.values.toList();
  }

  @override
  Future<void> saveStudy(Study study) async {
    _studies[study.id] = study;
  }

  @override
  Future<void> deleteStudy(String id) async {
    _studies.remove(id);
  }

  @override
  Future<Chapter> createChapter({
    required String studyId,
    required int sourceOrder,
    String? title,
    String? startingFen,
  }) async {
    final chapter = Chapter.create(
      studyId: studyId,
      sourceOrder: sourceOrder,
      title: title,
      startingFen: startingFen,
    );
    _chapters[chapter.id] = chapter;
    return chapter;
  }

  @override
  Future<Chapter?> getChapter(String id) async {
    var chapter = _chapters[id];
    if (chapter != null && chapter.root == null && _positionTrees.containsKey(id)) {
      chapter = chapter.copyWith(root: _positionTrees[id]);
      _chapters[id] = chapter;
    }
    return chapter;
  }

  @override
  Future<List<Chapter>> getChaptersByStudy(String studyId) async {
    return _chapters.values.where((c) => c.studyId == studyId).map((c) {
      if (c.root == null && _positionTrees.containsKey(c.id)) {
        return c.copyWith(root: _positionTrees[c.id]);
      }
      return c;
    }).toList();
  }

  @override
  Future<void> saveChapter(Chapter chapter) async {
    _chapters[chapter.id] = chapter;
    if (chapter.root != null) {
      _positionTrees[chapter.id] = chapter.root!;
    }
  }

  @override
  Future<void> savePositionTree(String chapterId, PositionNode root) async {
    _positionTrees[chapterId] = root;
    if (_chapters.containsKey(chapterId)) {
      _chapters[chapterId] = _chapters[chapterId]!.copyWith(root: root);
    }
  }

  @override
  Future<PositionNode?> getPositionTree(String chapterId) async {
    return _positionTrees[chapterId];
  }

  @override
  Future<RepertoireDecision?> getDecision(String id) async {
    return _decisions[id];
  }

  @override
  Future<List<RepertoireDecision>> getDecisionsByChapter(String chapterId) async {
    return _decisions.values.where((d) => d.chapterId == chapterId).toList();
  }

  @override
  Future<void> saveDecision(RepertoireDecision decision) async {
    _decisions[decision.id] = decision;
  }

  @override
  Future<List<RepertoireDecision>> getDecisionsDue() async {
    final now = DateTime.now();
    return _decisions.values
        .where((d) => _reviewStates[d.nodeId]?.nextDueAt != null &&
                      _reviewStates[d.nodeId]!.nextDueAt!.isBefore(now))
        .toList();
  }

  @override
  Future<ReviewState?> getReviewState(String decisionId) async {
    return _reviewStates[decisionId];
  }

  @override
  Future<void> saveReviewState(ReviewState state) async {
    _reviewStates[state.decisionId] = state;
  }

  @override
  Future<List<ReviewEvent>> getReviewEvents(String decisionId) async {
    return _reviewEvents[decisionId] ?? [];
  }

  @override
  Future<void> saveReviewEvent(ReviewEvent event) async {
    final events = _reviewEvents[event.decisionId] ?? [];
    events.add(event);
    _reviewEvents[event.decisionId] = events;
  }
}