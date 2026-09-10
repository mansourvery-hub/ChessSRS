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
  });
}