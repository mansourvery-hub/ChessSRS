import 'package:chess_repertoire_srs/application/review_service.dart';
import 'package:chess_repertoire_srs/chess/chess_service.dart';
import 'package:chess_repertoire_srs/domain/clock.dart';
import 'package:chess_repertoire_srs/domain/entities/position_node.dart';
import 'package:chess_repertoire_srs/domain/entities/position.dart';
import 'package:chess_repertoire_srs/domain/entities/repertoire_move.dart';
import 'package:chess_repertoire_srs/domain/repertoire_decision.dart';
import 'package:chess_repertoire_srs/domain/srs/simple_scheduler.dart';
import 'package:chess_repertoire_srs/persistence/in_memory_study_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late InMemoryStudyRepository repo;
  late ReviewService reviewService;
  late FixedClock testClock;

  setUp(() {
    repo = InMemoryStudyRepository();
    testClock = FixedClock(DateTime(2026, 9, 10, 12, 0));
    reviewService = ReviewService(
      studyRepository: repo,
      chessService: const ChessService(),
      scheduler: const SimpleScheduler(),
      clock: testClock,
    );
  });

  group('ReviewService', () {
    test('validates correct and incorrect user moves against decision', () async {
      final study = await repo.createStudy('Test Study');
      final chapter = await repo.createChapter(studyId: study.id, sourceOrder: 0);

      final root = PositionNode.create(
        positionKey: PositionKey.fromFen(ChessService.initialFen),
        fen: ChessService.initialFen,
      );

      final e4Move = const RepertoireMove(from: 'e2', to: 'e4', san: 'e4');
      final decision = RepertoireDecision.create(
        studyId: study.id,
        chapterId: chapter.id,
        nodeId: root.id,
        expectedMoves: [e4Move],
      );
      await repo.saveDecision(decision);

      // Correct move e2-e4
      final correctOutcome = await reviewService.validateMove(
        decision.id,
        'e2',
        'e4',
        null,
      );
      expect(correctOutcome.correct, isTrue);

      // Incorrect move d2-d4
      final incorrectOutcome = await reviewService.validateMove(
        decision.id,
        'd2',
        'd4',
        null,
      );
      expect(incorrectOutcome.correct, isFalse);
    });

    test('updates SRS review state in repository on correct answer', () async {
      final study = await repo.createStudy('Test Study');
      final chapter = await repo.createChapter(studyId: study.id, sourceOrder: 0);

      final decision = RepertoireDecision.create(
        studyId: study.id,
        chapterId: chapter.id,
        nodeId: 'node-1',
        expectedMoves: const [RepertoireMove(from: 'e2', to: 'e4', san: 'e4')],
      );
      await repo.saveDecision(decision);

      // Process correct recall
      final state1 = await reviewService.processReviewResult(decision.id, true);
      expect(state1.repetitionCount, 1);
      expect(state1.nextDueAt, testClock.now().add(const Duration(days: 1)));

      // Verify it's persisted in repo
      final persisted = await repo.getReviewState(decision.id);
      expect(persisted, isNotNull);
      expect(persisted!.repetitionCount, 1);
    });

    test('filters due decisions by study scope', () async {
      final studyA = await repo.createStudy('Study A');
      final chapterA = await repo.createChapter(studyId: studyA.id, sourceOrder: 0);
      final nodeA = PositionNode.create(
        positionKey: PositionKey.fromFen(ChessService.initialFen),
        fen: ChessService.initialFen,
      );
      final childA = PositionNode(
        id: 'nA1',
        positionKey: PositionKey.fromFen('fenA'),
        fen: 'fenA',
        incomingMove: const RepertoireMove(from: 'e2', to: 'e4', san: 'e4'),
        children: const [],
      );
      final treeA = PositionNode(
        id: nodeA.id,
        positionKey: nodeA.positionKey,
        fen: nodeA.fen,
        children: [childA],
      );
      await repo.savePositionTree(chapterA.id, treeA);

      final studyB = await repo.createStudy('Study B');
      final chapterB = await repo.createChapter(studyId: studyB.id, sourceOrder: 0);
      final nodeB = PositionNode.create(
        positionKey: PositionKey.fromFen(ChessService.initialFen),
        fen: ChessService.initialFen,
      );
      final childB = PositionNode(
        id: 'nB1',
        positionKey: PositionKey.fromFen('fenB'),
        fen: 'fenB',
        incomingMove: const RepertoireMove(from: 'd2', to: 'd4', san: 'd4'),
        children: const [],
      );
      final treeB = PositionNode(
        id: nodeB.id,
        positionKey: nodeB.positionKey,
        fen: nodeB.fen,
        children: [childB],
      );
      await repo.savePositionTree(chapterB.id, treeB);

      // All studies
      final allDue = await reviewService.getDueDecisions();
      expect(allDue, hasLength(2));

      // Filtered to study A only
      final studyADue = await reviewService.getDueDecisions(studyId: studyA.id);
      expect(studyADue, hasLength(1));
      expect(studyADue.first.studyId, studyA.id);
    });
  });
}