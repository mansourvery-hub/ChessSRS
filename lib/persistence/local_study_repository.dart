import 'dart:convert';
import 'dart:io';
import 'package:chess_repertoire_srs/core/ids.dart';
import 'package:chess_repertoire_srs/domain/entities/chapter.dart';
import 'package:chess_repertoire_srs/domain/entities/position.dart';
import 'package:chess_repertoire_srs/domain/entities/position_node.dart';
import 'package:chess_repertoire_srs/domain/entities/repertoire_move.dart';
import 'package:chess_repertoire_srs/domain/entities/study.dart';
import 'package:chess_repertoire_srs/domain/repertoire_decision.dart';
import 'package:chess_repertoire_srs/domain/srs/review_event.dart';
import 'package:chess_repertoire_srs/domain/srs/review_state.dart';
import 'package:chess_repertoire_srs/persistence/study_repository.dart';

/// File-backed local persistence store implementing [StudyRepository].
///
/// Keeps an in-memory cache for synchronous read latency (<16ms critical path)
/// while writing updates incrementally to disk.
class LocalStudyRepository implements StudyRepository {
  LocalStudyRepository({required this.storageDirectory});

  final Directory storageDirectory;

  final Map<String, Study> _studies = {};
  final Map<String, Chapter> _chapters = {};
  final Map<String, PositionNode> _positionTrees = {};
  final Map<String, RepertoireDecision> _decisions = {};
  final Map<String, ReviewState> _reviewStates = {};
  final Map<String, List<ReviewEvent>> _reviewEvents = {};

  bool _initialized = false;

  File get _studiesFile => File('${storageDirectory.path}/studies.json');
  File get _chaptersFile => File('${storageDirectory.path}/chapters.json');
  File get _decisionsFile => File('${storageDirectory.path}/decisions.json');
  File get _reviewStatesFile => File('${storageDirectory.path}/review_states.json');
  File get _reviewEventsFile => File('${storageDirectory.path}/review_events.json');
  File _treeFile(String chapterId) => File('${storageDirectory.path}/tree_$chapterId.json');

  /// Initialize and load all persisted entities from disk into memory.
  Future<void> initialize() async {
    if (_initialized) return;
    if (!await storageDirectory.exists()) {
      await storageDirectory.create(recursive: true);
    }

    await _loadStudies();
    await _loadChapters();
    await _loadDecisions();
    await _loadReviewStates();
    await _loadReviewEvents();
    _initialized = true;
  }

  // --- Studies ---

  @override
  Future<Study> createStudy(String title) async {
    final study = Study(
      id: uuid.v4(),
      title: title,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _studies[study.id] = study;
    await _persistStudies();
    return study;
  }

  @override
  Future<Study?> getStudy(String id) async => _studies[id];

  @override
  Future<List<Study>> getAllStudies() async => _studies.values.toList();

  @override
  Future<void> saveStudy(Study study) async {
    _studies[study.id] = study;
    await _persistStudies();
  }

  @override
  Future<void> deleteStudy(String id) async {
    _studies.remove(id);
    await _persistStudies();
  }

  Future<void> _loadStudies() async {
    if (!await _studiesFile.exists()) return;
    try {
      final jsonStr = await _studiesFile.readAsString();
      final list = jsonDecode(jsonStr) as List<dynamic>;
      for (final item in list) {
        final map = item as Map<String, dynamic>;
        final study = Study(
          id: map['id'] as String,
          title: map['title'] as String,
          createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt'] as String) : null,
          updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt'] as String) : null,
        );
        _studies[study.id] = study;
      }
    } catch (_) {}
  }

  Future<void> _persistStudies() async {
    final data = _studies.values.map((s) => {
      'id': s.id,
      'title': s.title,
      'createdAt': s.createdAt?.toIso8601String(),
      'updatedAt': s.updatedAt?.toIso8601String(),
    }).toList();
    await _studiesFile.writeAsString(jsonEncode(data));
  }

  // --- Chapters ---

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
    await _persistChapters();
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
    return _chapters.values.where((c) => c.studyId == studyId).toList();
  }

  @override
  Future<void> saveChapter(Chapter chapter) async {
    _chapters[chapter.id] = chapter;
    if (chapter.root != null) {
      _positionTrees[chapter.id] = chapter.root!;
      await _persistTree(chapter.id, chapter.root!);
    }
    await _persistChapters();
  }

  Future<void> _loadChapters() async {
    if (!await _chaptersFile.exists()) return;
    try {
      final jsonStr = await _chaptersFile.readAsString();
      final list = jsonDecode(jsonStr) as List<dynamic>;
      for (final item in list) {
        final map = item as Map<String, dynamic>;
        final chapterId = map['id'] as String;
        final rootTree = await _loadTree(chapterId);
        if (rootTree != null) {
          _positionTrees[chapterId] = rootTree;
        }

        final chapter = Chapter(
          id: chapterId,
          studyId: map['studyId'] as String,
          sourceOrder: map['sourceOrder'] as int,
          title: map['title'] as String?,
          startingFen: map['startingFen'] as String?,
          root: rootTree,
          createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt'] as String) : null,
        );
        _chapters[chapter.id] = chapter;
      }
    } catch (_) {}
  }

  Future<void> _persistChapters() async {
    final data = _chapters.values.map((c) => {
      'id': c.id,
      'studyId': c.studyId,
      'sourceOrder': c.sourceOrder,
      'title': c.title,
      'startingFen': c.startingFen,
      'createdAt': c.createdAt?.toIso8601String(),
    }).toList();
    await _chaptersFile.writeAsString(jsonEncode(data));
  }

  // --- Position Trees ---

  @override
  Future<void> savePositionTree(String chapterId, PositionNode root) async {
    _positionTrees[chapterId] = root;
    if (_chapters.containsKey(chapterId)) {
      _chapters[chapterId] = _chapters[chapterId]!.copyWith(root: root);
    }
    await _persistTree(chapterId, root);
  }

  @override
  Future<PositionNode?> getPositionTree(String chapterId) async {
    if (_positionTrees.containsKey(chapterId)) {
      return _positionTrees[chapterId];
    }
    final tree = await _loadTree(chapterId);
    if (tree != null) {
      _positionTrees[chapterId] = tree;
    }
    return tree;
  }

  Future<void> _persistTree(String chapterId, PositionNode root) async {
    final jsonMap = _nodeToJson(root);
    await _treeFile(chapterId).writeAsString(jsonEncode(jsonMap));
  }

  Future<PositionNode?> _loadTree(String chapterId) async {
    final file = _treeFile(chapterId);
    if (!await file.exists()) return null;
    try {
      final jsonStr = await file.readAsString();
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return _nodeFromJson(map);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _nodeToJson(PositionNode node) {
    return {
      'id': node.id,
      'fen': node.fen,
      'incomingMove': node.incomingMove != null
          ? {
              'from': node.incomingMove!.from,
              'to': node.incomingMove!.to,
              'promotion': node.incomingMove!.promotion,
              'san': node.incomingMove!.san,
            }
          : null,
      'comment': node.comment,
      'children': node.children.map(_nodeToJson).toList(),
    };
  }

  PositionNode _nodeFromJson(Map<String, dynamic> map) {
    RepertoireMove? incomingMove;
    if (map['incomingMove'] != null) {
      final m = map['incomingMove'] as Map<String, dynamic>;
      incomingMove = RepertoireMove(
        from: m['from'] as String,
        to: m['to'] as String,
        promotion: m['promotion'] as String?,
        san: m['san'] as String? ?? '',
      );
    }

    final childrenList = (map['children'] as List<dynamic>?)
            ?.map((c) => _nodeFromJson(c as Map<String, dynamic>))
            .toList() ??
        const [];

    final fen = map['fen'] as String;
    return PositionNode(
      id: map['id'] as String,
      positionKey: PositionKey.fromFen(fen),
      fen: fen,
      incomingMove: incomingMove,
      comment: map['comment'] as String?,
      children: childrenList,
    );
  }

  // --- Decisions ---

  @override
  Future<RepertoireDecision?> getDecision(String id) async => _decisions[id];

  @override
  Future<List<RepertoireDecision>> getDecisionsByChapter(String chapterId) async {
    return _decisions.values.where((d) => d.chapterId == chapterId).toList();
  }

  @override
  Future<void> saveDecision(RepertoireDecision decision) async {
    _decisions[decision.id] = decision;
    await _persistDecisions();
  }

  @override
  Future<List<RepertoireDecision>> getDecisionsDue() async {
    final now = DateTime.now();
    return _decisions.values.where((d) {
      final state = _reviewStates[d.id];
      if (state == null) return true; // Unreviewed items are due
      return state.isDueAt(now);
    }).toList();
  }

  Future<void> _loadDecisions() async {
    if (!await _decisionsFile.exists()) return;
    try {
      final jsonStr = await _decisionsFile.readAsString();
      final list = jsonDecode(jsonStr) as List<dynamic>;
      for (final item in list) {
        final map = item as Map<String, dynamic>;
        final moves = (map['expectedMoves'] as List<dynamic>)
            .map((m) => RepertoireMove(
                  from: m['from'] as String,
                  to: m['to'] as String,
                  promotion: m['promotion'] as String?,
                  san: m['san'] as String? ?? '',
                ))
            .toList();

        final decision = RepertoireDecision(
          id: map['id'] as String,
          studyId: map['studyId'] as String,
          chapterId: map['chapterId'] as String,
          nodeId: map['nodeId'] as String,
          expectedMoves: moves,
        );
        _decisions[decision.id] = decision;
      }
    } catch (_) {}
  }

  Future<void> _persistDecisions() async {
    final data = _decisions.values.map((d) => {
      'id': d.id,
      'studyId': d.studyId,
      'chapterId': d.chapterId,
      'nodeId': d.nodeId,
      'expectedMoves': d.expectedMoves.map((m) => {
        'from': m.from,
        'to': m.to,
        'promotion': m.promotion,
        'san': m.san,
      }).toList(),
    }).toList();
    await _decisionsFile.writeAsString(jsonEncode(data));
  }

  // --- Review States & Events ---

  @override
  Future<ReviewState?> getReviewState(String decisionId) async => _reviewStates[decisionId];

  @override
  Future<void> saveReviewState(ReviewState state) async {
    _reviewStates[state.decisionId] = state;
    await _persistReviewStates();
  }

  Future<void> _loadReviewStates() async {
    if (!await _reviewStatesFile.exists()) return;
    try {
      final jsonStr = await _reviewStatesFile.readAsString();
      final list = jsonDecode(jsonStr) as List<dynamic>;
      for (final item in list) {
        final map = item as Map<String, dynamic>;
        final state = ReviewState(
          itemId: map['itemId'] as String,
          decisionId: map['decisionId'] as String,
          firstReviewedAt: map['firstReviewedAt'] != null ? DateTime.parse(map['firstReviewedAt'] as String) : null,
          lastReviewedAt: map['lastReviewedAt'] != null ? DateTime.parse(map['lastReviewedAt'] as String) : null,
          nextDueAt: map['nextDueAt'] != null ? DateTime.parse(map['nextDueAt'] as String) : null,
          repetitionCount: map['repetitionCount'] as int? ?? 0,
          lapseCount: map['lapseCount'] as int? ?? 0,
          stability: (map['stability'] as num?)?.toDouble() ?? 0.0,
          difficulty: (map['difficulty'] as num?)?.toDouble() ?? 0.0,
        );
        _reviewStates[state.decisionId] = state;
      }
    } catch (_) {}
  }

  Future<void> _persistReviewStates() async {
    final data = _reviewStates.values.map((s) => {
      'itemId': s.itemId,
      'decisionId': s.decisionId,
      'firstReviewedAt': s.firstReviewedAt?.toIso8601String(),
      'lastReviewedAt': s.lastReviewedAt?.toIso8601String(),
      'nextDueAt': s.nextDueAt?.toIso8601String(),
      'repetitionCount': s.repetitionCount,
      'lapseCount': s.lapseCount,
      'stability': s.stability,
      'difficulty': s.difficulty,
    }).toList();
    await _reviewStatesFile.writeAsString(jsonEncode(data));
  }

  @override
  Future<List<ReviewEvent>> getReviewEvents(String decisionId) async {
    return _reviewEvents[decisionId] ?? [];
  }

  @override
  Future<void> saveReviewEvent(ReviewEvent event) async {
    final list = _reviewEvents[event.decisionId] ?? [];
    list.add(event);
    _reviewEvents[event.decisionId] = list;
    await _persistReviewEvents();
  }

  Future<void> _loadReviewEvents() async {
    if (!await _reviewEventsFile.exists()) return;
    try {
      final jsonStr = await _reviewEventsFile.readAsString();
      final list = jsonDecode(jsonStr) as List<dynamic>;
      for (final item in list) {
        final map = item as Map<String, dynamic>;
        final event = ReviewEvent(
          itemId: map['itemId'] as String,
          decisionId: map['decisionId'] as String,
          when: DateTime.parse(map['when'] as String),
          outcome: map['outcome'] as bool,
          interval: Duration(milliseconds: map['intervalMs'] as int? ?? 0),
          oldState: (map['oldState'] as Map<String, dynamic>?) ?? const {},
          newState: (map['newState'] as Map<String, dynamic>?) ?? const {},
        );
        final events = _reviewEvents[event.decisionId] ?? [];
        events.add(event);
        _reviewEvents[event.decisionId] = events;
      }
    } catch (_) {}
  }

  Future<void> _persistReviewEvents() async {
    final allEvents = _reviewEvents.values.expand((l) => l).map((e) => {
      'itemId': e.itemId,
      'decisionId': e.decisionId,
      'when': e.when.toIso8601String(),
      'outcome': e.outcome,
      'intervalMs': e.interval.inMilliseconds,
      'oldState': e.oldState,
      'newState': e.newState,
    }).toList();
    await _reviewEventsFile.writeAsString(jsonEncode(allEvents));
  }
}