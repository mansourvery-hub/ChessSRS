// Copyright (C) 2024 ChessSRS contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:chess_srs/src/domain/domain.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReviewSession Engine', () {
    late FixedClock clock;
    late DateTime baseTime;

    setUp(() {
      baseTime = DateTime.utc(2026, 9, 16, 10, 0, 0);
      clock = FixedClock(baseTime);
    });

    // Helper to build a basic study and chapter
    (Study, Chapter, List<RepertoireDecision>) buildTestRepertoire() {
      final study = Study(
        id: 'study-openings',
        title: 'Openings',
        createdAt: baseTime,
        updatedAt: baseTime,
      );

      // Root -> 1. e4 (dec-1) -> 1... e5 -> 2. Nf3 (dec-2) -> 2... Nc6 -> 3. Bc4 (dec-3)
      const rootNode = RepertoireNode(
        id: 'node-root',
        fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
        fenKey: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq -',
        children: [
          RepertoireNode(
            id: 'node-e4',
            fen: 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1',
            fenKey: 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq -',
            incomingMove: RepertoireMove(from: 'e2', to: 'e4', san: 'e4'),
            children: [
              RepertoireNode(
                id: 'node-e5',
                fen: 'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2',
                fenKey: 'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq -',
                incomingMove: RepertoireMove(from: 'e7', to: 'e5', san: 'e5'),
                children: [
                  RepertoireNode(
                    id: 'node-nf3',
                    fen: 'rnbqkbnr/pppp1ppp/8/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq - 1 2',
                    fenKey: 'rnbqkbnr/pppp1ppp/8/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq -',
                    incomingMove: RepertoireMove(from: 'g1', to: 'f3', san: 'Nf3'),
                    children: [
                      RepertoireNode(
                        id: 'node-nc6',
                        fen: 'r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3',
                        fenKey: 'r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq -',
                        incomingMove: RepertoireMove(from: 'b8', to: 'c6', san: 'Nc6'),
                        children: [
                          RepertoireNode(
                            id: 'node-bc4',
                            fen:
                                'r1bqkbnr/pppp1ppp/2n5/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R b KQkq - 3 3',
                            fenKey: 'r1bqkbnr/pppp1ppp/2n5/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R b KQkq -',
                            incomingMove: RepertoireMove(from: 'f1', to: 'c4', san: 'Bc4'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      );

      final chapter = Chapter(
        id: 'chapter-italian',
        studyId: study.id,
        sourceOrder: 0,
        title: 'Italian Game',
        startingFen: rootNode.fen,
        root: rootNode,
        createdAt: baseTime,
      );

      final decisions = [
        const RepertoireDecision(
          id: 'dec-1',
          studyId: 'study-openings',
          chapterId: 'chapter-italian',
          nodeId: 'node-root',
          expectedMoves: [RepertoireMove(from: 'e2', to: 'e4', san: 'e4')],
        ),
        const RepertoireDecision(
          id: 'dec-2',
          studyId: 'study-openings',
          chapterId: 'chapter-italian',
          nodeId: 'node-e5',
          expectedMoves: [RepertoireMove(from: 'g1', to: 'f3', san: 'Nf3')],
        ),
        const RepertoireDecision(
          id: 'dec-3',
          studyId: 'study-openings',
          chapterId: 'chapter-italian',
          nodeId: 'node-nc6',
          expectedMoves: [RepertoireMove(from: 'f1', to: 'c4', san: 'Bc4')],
        ),
      ];

      return (study, chapter, decisions);
    }

    test('initializes empty session when no decisions are due', () {
      final (study, chapter, decisions) = buildTestRepertoire();
      // Schedule all decisions in the future
      final futureStates = {
        for (final d in decisions)
          d.id: ReviewState(decisionId: d.id, nextDueAt: baseTime.add(const Duration(days: 2))),
      };

      final engine = ReviewEngine(clock: clock);
      final session = engine.createSession(
        studies: [study],
        chapters: [chapter],
        decisions: decisions,
        reviewStates: futureStates,
      );

      expect(session.isComplete, isTrue);
      expect(session.currentPrompt, isNull);
      expect(session.remainingDueCount, 0);
    });

    test('validates correct move and performs auto-traversal through opponent reply', () {
      final (study, chapter, decisions) = buildTestRepertoire();
      // All decisions are due (unreviewed)
      final engine = ReviewEngine(clock: clock);
      final session = engine.createSession(
        studies: [study],
        chapters: [chapter],
        decisions: decisions,
        reviewStates: const {},
      );

      expect(session.isComplete, isFalse);
      expect(session.remainingDueCount, 3);
      expect(session.currentPrompt?.nodeId, 'node-root');
      expect(session.currentPrompt?.sideToMove, Side.white);

      // User plays correct move 1. e4
      final result = session.submitMove(from: 'e2', to: 'e4');

      expect(result.isCorrect, isTrue);
      expect(result.updatedState.repetitionCount, 1);
      expect(result.updatedState.nextDueAt, baseTime.add(const Duration(days: 1)));

      // Auto-played moves should include opponent reply: 1... e5
      expect(result.autoPlayedMoves.length, 1);
      final opponentMove = result.autoPlayedMoves.first;
      expect(opponentMove.isUserMove, isFalse);
      expect(opponentMove.move.san, 'e5');

      // Next prompt should be stopped at node-e5 (dec-2: 2. Nf3)
      expect(result.nextPrompt, isNotNull);
      expect(result.nextPrompt?.nodeId, 'node-e5');
      expect(result.nextPrompt?.decision.id, 'dec-2');
      expect(session.remainingDueCount, 2);
      expect(session.completedCount, 1);
    });

    test('auto-traversal skips already-learned (non-due) user moves (Invariant §2.4)', () {
      final (study, chapter, decisions) = buildTestRepertoire();
      // dec-1 is DUE
      // dec-2 (Nf3) is LEARNED and NOT due (due in 5 days)
      // dec-3 (Bc4) is DUE
      final reviewStates = {
        'dec-2': ReviewState(
          decisionId: 'dec-2',
          nextDueAt: baseTime.add(const Duration(days: 5)),
          repetitionCount: 2,
        ),
      };

      final engine = ReviewEngine(clock: clock);
      final session = engine.createSession(
        studies: [study],
        chapters: [chapter],
        decisions: decisions,
        reviewStates: reviewStates,
      );

      expect(session.remainingDueCount, 2); // dec-1 and dec-3
      expect(session.currentPrompt?.decision.id, 'dec-1');

      // User plays 1. e4
      final result = session.submitMove(from: 'e2', to: 'e4');

      expect(result.isCorrect, isTrue);

      // Auto-played should contain:
      // 1. Opponent 1... e5 (isUserMove: false)
      // 2. Learned user move 2. Nf3 (isUserMove: true)
      // 3. Opponent reply 2... Nc6 (isUserMove: false)
      expect(result.autoPlayedMoves.length, 3);
      expect(result.autoPlayedMoves[0].move.san, 'e5');
      expect(result.autoPlayedMoves[0].isUserMove, isFalse);
      expect(result.autoPlayedMoves[1].move.san, 'Nf3');
      expect(result.autoPlayedMoves[1].isUserMove, isTrue);
      expect(result.autoPlayedMoves[2].move.san, 'Nc6');
      expect(result.autoPlayedMoves[2].isUserMove, isFalse);

      // Next prompt should stop at dec-3 (3. Bc4), which is due!
      expect(result.nextPrompt?.decision.id, 'dec-3');
      expect(session.remainingDueCount, 1);
    });

    test('validates incorrect move against repertoire and re-queues failed decision', () {
      final (study, chapter, decisions) = buildTestRepertoire();
      final engine = ReviewEngine(clock: clock);
      final session = engine.createSession(
        studies: [study],
        chapters: [chapter],
        decisions: decisions,
        reviewStates: const {},
      );

      // User plays 1. d4 instead of prepared 1. e4
      final result = session.submitMove(from: 'd2', to: 'd4');

      expect(result.isCorrect, isFalse);
      expect(result.movePlayed.from, 'd2');
      expect(result.movePlayed.to, 'd4');
      expect(result.expectedMoves.first.san, 'e4');
      expect(result.updatedState.lapseCount, 1);
      expect(result.updatedState.repetitionCount, 0);
      expect(result.updatedState.nextDueAt, baseTime.add(const Duration(days: 1)));

      // Current prompt remains for user feedback
      expect(session.currentPrompt?.decision.id, 'dec-1');

      // User acknowledges feedback and continues
      session.continueAfterIncorrect();

      // Next prompt advances to the next due item in queue (dec-2)
      expect(session.currentPrompt?.decision.id, 'dec-2');

      // dec-1 is still in the queue at the end
      expect(session.remainingDueCount, 3);
    });

    test('filtering by ReviewScope.study confines review to matching study', () {
      final (studyA, chapterA, decisionsA) = buildTestRepertoire();

      const studyB = Study(id: 'study-b', title: 'Study B');
      final chapterB = Chapter(id: 'ch-b', studyId: studyB.id, sourceOrder: 0);
      const decB = RepertoireDecision(
        id: 'dec-b1',
        studyId: 'study-b',
        chapterId: 'ch-b',
        nodeId: 'node-b1',
        expectedMoves: [RepertoireMove(from: 'c2', to: 'c4')],
      );

      final engine = ReviewEngine(clock: clock);

      // Scope to study-openings only
      final session = engine.createSession(
        studies: [studyA, studyB],
        chapters: [chapterA, chapterB],
        decisions: [...decisionsA, decB],
        reviewStates: const {},
        scope: const ReviewScope.study('study-openings'),
      );

      expect(session.remainingDueCount, 3);
      expect(session.currentPrompt?.studyId, 'study-openings');
    });

    test('deterministic clock advancement surfaces due items over time (Invariant §3.2)', () {
      final (study, chapter, decisions) = buildTestRepertoire();
      final engine = ReviewEngine(clock: clock);

      // All decisions scheduled for tomorrow (baseTime + 24 hours)
      final tomorrow = baseTime.add(const Duration(days: 1));
      final futureStates = {
        for (final d in decisions) d.id: ReviewState(decisionId: d.id, nextDueAt: tomorrow),
      };

      // Initially at baseTime: nothing is due
      var session = engine.createSession(
        studies: [study],
        chapters: [chapter],
        decisions: decisions,
        reviewStates: futureStates,
      );
      expect(session.isComplete, isTrue);

      // Advance clock by 25 hours: all decisions become due!
      clock.advance(const Duration(hours: 25));

      session = engine.createSession(
        studies: [study],
        chapters: [chapter],
        decisions: decisions,
        reviewStates: futureStates,
      );
      expect(session.isComplete, isFalse);
      expect(session.remainingDueCount, 3);
    });

    test('skip moves current prompt to the back of queue', () {
      final (study, chapter, decisions) = buildTestRepertoire();
      final engine = ReviewEngine(clock: clock);
      final session = engine.createSession(
        studies: [study],
        chapters: [chapter],
        decisions: decisions,
        reviewStates: const {},
      );

      expect(session.currentPrompt?.decision.id, 'dec-1');

      final nextPrompt = session.skip();
      expect(nextPrompt?.decision.id, 'dec-2');

      // dec-1 is now at the end of the queue
      expect(session.remainingDueCount, 3);
    });

    test(
      'ReviewMode.practice tests all decisions even when none are due, without modifying states',
      () {
        final (study, chapter, decisions) = buildTestRepertoire();
        final engine = ReviewEngine(clock: clock);

        // All decisions scheduled for next month (not due)
        final future = baseTime.add(const Duration(days: 30));
        final futureStates = {
          for (final d in decisions)
            d.id: ReviewState(
              decisionId: d.id,
              nextDueAt: future,
              repetitionCount: 5,
              stability: 30.0,
            ),
        };

        // In standard SRS mode: session is empty (isComplete == true)
        final srsSession = engine.createSession(
          studies: [study],
          chapters: [chapter],
          decisions: decisions,
          reviewStates: futureStates,
          mode: ReviewMode.srs,
        );
        expect(srsSession.isComplete, isTrue);

        // In practice mode: all 3 decisions are queued for training!
        final practiceSession = engine.createSession(
          studies: [study],
          chapters: [chapter],
          decisions: decisions,
          reviewStates: futureStates,
          mode: ReviewMode.practice,
        );
        expect(practiceSession.isComplete, isFalse);
        expect(practiceSession.remainingDueCount, 3);
        expect(practiceSession.currentPrompt?.decision.id, 'dec-1');

        // Submit correct move in practice mode
        final result1 = practiceSession.submitMove(from: 'e2', to: 'e4');
        expect(result1.isCorrect, isTrue);
        // Invariant: Practice mode produces NO ReviewEvent and preserves previous ReviewState
        expect(result1.event, isNull);
        expect(result1.updatedState.repetitionCount, 5); // Unchanged!
        expect(result1.updatedState.stability, 30.0); // Unchanged!

        // Submit incorrect move in practice mode
        final result2 = practiceSession.submitMove(from: 'd2', to: 'd4');
        expect(result2.isCorrect, isFalse);
        expect(result2.event, isNull);
        expect(result2.updatedState.lapseCount, 0); // No lapse recorded!
        expect(result2.updatedState.repetitionCount, 5); // Repetitions not reset!
      },
    );
  });
}
