import 'dart:io';
import 'package:chess_repertoire_srs/chess/chess_service.dart';
import 'package:chess_repertoire_srs/domain/entities/position.dart';
import 'package:chess_repertoire_srs/domain/entities/position_node.dart';
import 'package:chess_repertoire_srs/domain/entities/repertoire_move.dart';
import 'package:chess_repertoire_srs/domain/repertoire_decision.dart';
import 'package:chess_repertoire_srs/domain/srs/review_event.dart';
import 'package:chess_repertoire_srs/domain/srs/review_state.dart';
import 'package:chess_repertoire_srs/persistence/local_study_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('srs_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('LocalStudyRepository', () {
    test('persists studies, chapters, position trees, and decisions across restarts', () async {
      // 1. Write data in session 1
      final repo1 = LocalStudyRepository(storageDirectory: tempDir);
      await repo1.initialize();

      final study = await repo1.createStudy('Sicilian Najdorf');
      final chapter = await repo1.createChapter(
        studyId: study.id,
        sourceOrder: 0,
        title: 'Main Line',
        startingFen: ChessService.initialFen,
      );

      final root = PositionNode.create(
        positionKey: PositionKey.fromFen(ChessService.initialFen),
        fen: ChessService.initialFen,
      );
      final e4Child = PositionNode(
        id: 'node-e4',
        positionKey: PositionKey.fromFen('rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1'),
        fen: 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1',
        incomingMove: const RepertoireMove(from: 'e2', to: 'e4', san: 'e4'),
        children: const [],
      );
      final tree = PositionNode(
        id: root.id,
        positionKey: root.positionKey,
        fen: root.fen,
        children: [e4Child],
      );
      await repo1.savePositionTree(chapter.id, tree);

      final decision = RepertoireDecision.create(
        studyId: study.id,
        chapterId: chapter.id,
        nodeId: root.id,
        expectedMoves: const [RepertoireMove(from: 'e2', to: 'e4', san: 'e4')],
      );
      await repo1.saveDecision(decision);

      final reviewState = ReviewState(
        itemId: decision.id,
        decisionId: decision.id,
        repetitionCount: 2,
        nextDueAt: DateTime(2026, 9, 15, 12, 0),
      );
      await repo1.saveReviewState(reviewState);

      final reviewEvent = ReviewEvent(
        itemId: decision.id,
        decisionId: decision.id,
        when: DateTime(2026, 9, 10, 10, 0),
        outcome: true,
        interval: const Duration(days: 5),
        oldState: const {},
        newState: const {},
      );
      await repo1.saveReviewEvent(reviewEvent);

      // 2. Open brand new repository instance pointing to the same directory (Simulate app restart)
      final repo2 = LocalStudyRepository(storageDirectory: tempDir);
      await repo2.initialize();

      final loadedStudies = await repo2.getAllStudies();
      expect(loadedStudies, hasLength(1));
      expect(loadedStudies.first.title, 'Sicilian Najdorf');

      final loadedChapters = await repo2.getChaptersByStudy(study.id);
      expect(loadedChapters, hasLength(1));
      expect(loadedChapters.first.title, 'Main Line');

      final loadedTree = await repo2.getPositionTree(chapter.id);
      expect(loadedTree, isNotNull);
      expect(loadedTree!.children, hasLength(1));
      expect(loadedTree.children.first.incomingMove?.san, 'e4');

      final loadedDecision = await repo2.getDecision(decision.id);
      expect(loadedDecision, isNotNull);
      expect(loadedDecision!.expectedMoves.first.san, 'e4');

      final loadedState = await repo2.getReviewState(decision.id);
      expect(loadedState, isNotNull);
      expect(loadedState!.repetitionCount, 2);

      final loadedEvents = await repo2.getReviewEvents(decision.id);
      expect(loadedEvents, hasLength(1));
      expect(loadedEvents.first.outcome, isTrue);
    });

    test('updates review states incrementally without corrupting existing data', () async {
      final repo = LocalStudyRepository(storageDirectory: tempDir);
      await repo.initialize();

      final state1 = ReviewState(
        itemId: 'd1',
        decisionId: 'd1',
        repetitionCount: 1,
        nextDueAt: DateTime(2026, 9, 11),
      );
      await repo.saveReviewState(state1);

      final state2 = ReviewState(
        itemId: 'd2',
        decisionId: 'd2',
        repetitionCount: 3,
        nextDueAt: DateTime(2026, 9, 20),
      );
      await repo.saveReviewState(state2);

      // Reload
      final repoRestarted = LocalStudyRepository(storageDirectory: tempDir);
      await repoRestarted.initialize();

      final loaded1 = await repoRestarted.getReviewState('d1');
      final loaded2 = await repoRestarted.getReviewState('d2');

      expect(loaded1?.repetitionCount, 1);
      expect(loaded2?.repetitionCount, 3);
    });
  });
}