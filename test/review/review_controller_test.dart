// Copyright (C) 2024 ChessSRS contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:chess_srs/src/domain/domain.dart';
import 'package:chess_srs/src/model/common/service/sound_service.dart';
import 'package:chess_srs/src/persistence/persistence.dart';
import 'package:chess_srs/src/review/review_controller.dart';
import 'package:chess_srs/src/review/review_service.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../binding.dart';
import '../model/common/service/fake_sound_service.dart';

void main() {
  setUpAll(() {
    TestLichessBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('ReviewController', () {
    late Database db;
    late SqliteStudyRepository repo;
    late FixedClock clock;

    setUp(() async {
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      final batch = db.batch();
      createSrsTables(batch);
      await batch.commit();
      repo = SqliteStudyRepository(db);
      clock = FixedClock(DateTime.utc(2026, 9, 16, 10, 0));
    });

    tearDown(() async {
      await db.close();
    });

    ProviderContainer createContainer() {
      final container = ProviderContainer(
        overrides: [
          srsStudyRepositoryProvider.overrideWith((ref) => repo),
          clockProvider.overrideWithValue(clock),
          soundServiceProvider.overrideWithValue(FakeSoundService()),
          reviewServiceProvider.overrideWith(
            (ref) =>
                ReviewService(repository: repo, scheduler: const SimpleScheduler(), clock: clock),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('initializes with empty repository: 0 studies, no prompt', () async {
      final container = createContainer();
      final state = await container.read(reviewControllerProvider.future);

      expect(state.hasStudies, isFalse);
      expect(state.studies, isEmpty);
      expect(state.totalDueCount, 0);
      expect(state.currentPrompt, isNull);
      expect(state.boardPosition, isNull);
    });

    test('imports PGN, initializes session with due prompt and board orientation', () async {
      final container = createContainer();
      final controller = container.read(reviewControllerProvider.notifier);

      // Import French Defence for Black
      const pgn = '''
[Event "French Defence"]
[Site "?"]
[Date "2026.09.16"]
[Round "1"]
[White "Opponent"]
[Black "Hero"]
[Result "*"]

1. e4 e6 2. d4 d5 *
''';

      final importResult = await controller.importPgnText(
        pgnText: pgn,
        title: 'French Defence',
        repertoireSide: Side.black,
      );

      expect(importResult.decisions.length, 2); // e6 and d5 for Black

      final state = container.read(reviewControllerProvider).requireValue;
      expect(state.hasStudies, isTrue);
      expect(state.scope, ReviewScope.study(importResult.study.id));
      expect(state.totalDueCount, 2);
      expect(state.currentPrompt, isNotNull);
      expect(state.boardOrientation, Side.black);
      expect(state.boardPosition, isNotNull);

      // Pre-move animation: starts at parent position (White's turn before 1. e4),
      // then animates White's 1. e4 onto the board so Black sees opponent's move!
      expect(state.boardPosition!.turn, Side.white);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      final stateAfterPreMove = container.read(reviewControllerProvider).requireValue;
      expect(stateAfterPreMove.boardPosition!.turn, Side.black);
      expect(stateAfterPreMove.lastMove, const NormalMove(from: Square.e2, to: Square.e4));
    });

    test('handles correct move and advances queue', () async {
      final container = createContainer();
      final controller = container.read(reviewControllerProvider.notifier);

      const pgn = '''
[Event "Italian Game"]
1. e4 e5 2. Nf3 Nc6 *
''';

      await controller.importPgnText(pgnText: pgn, title: 'Italian', repertoireSide: Side.white);

      var state = container.read(reviewControllerProvider).requireValue;
      expect(state.totalDueCount, 2);
      expect(state.boardOrientation, Side.white);

      // Play 1. e4
      final result = await controller.onUserMove(const NormalMove(from: Square.e2, to: Square.e4));

      expect(result, isNotNull);
      expect(result!.isCorrect, isTrue);

      state = container.read(reviewControllerProvider).requireValue;
      expect(state.feedback, ReviewFeedback.none);
      expect(state.totalDueCount, 1);
      // Auto-traversal played 1... e5, so next prompt is for 2. Nf3
      expect(state.currentPrompt, isNotNull);
      expect(state.currentPrompt!.expectedMoves.first.san, 'Nf3');
    });

    test('handles incorrect move (lapse) and allows user to reguess on the board', () async {
      final container = createContainer();
      final controller = container.read(reviewControllerProvider.notifier);

      const pgn = '''
[Event "Queen Pawn"]
1. d4 d5 *
''';

      await controller.importPgnText(pgnText: pgn, title: 'Queen Pawn', repertoireSide: Side.white);

      // Play wrong move 1. e4 instead of 1. d4
      final result1 = await controller.onUserMove(const NormalMove(from: Square.e2, to: Square.e4));

      expect(result1, isNotNull);
      expect(result1!.isCorrect, isFalse);

      var state = container.read(reviewControllerProvider).requireValue;
      expect(state.feedback, ReviewFeedback.incorrect);
      expect(state.expectedMove, isNotNull);
      expect(state.expectedMove!.san, 'd4');

      // Reguess on board with correct move 1. d4
      final result2 = await controller.onUserMove(const NormalMove(from: Square.d2, to: Square.d4));

      expect(result2, isNotNull);
      expect(result2!.isCorrect, isTrue);

      state = container.read(reviewControllerProvider).requireValue;
      expect(state.feedback, ReviewFeedback.none);
      expect(state.expectedMove, isNull);
    });

    test(
      'handles incorrect move (lapse), shows expected move, and continues on acknowledge',
      () async {
        final container = createContainer();
        final controller = container.read(reviewControllerProvider.notifier);

        const pgn = '''
[Event "Queen Pawn"]
1. d4 d5 *
''';

        await controller.importPgnText(
          pgnText: pgn,
          title: 'Queen Pawn',
          repertoireSide: Side.white,
        );

        // Play wrong move 1. e4 instead of 1. d4
        final result = await controller.onUserMove(
          const NormalMove(from: Square.e2, to: Square.e4),
        );

        expect(result, isNotNull);
        expect(result!.isCorrect, isFalse);

        var state = container.read(reviewControllerProvider).requireValue;
        expect(state.feedback, ReviewFeedback.incorrect);
        expect(state.expectedMove, isNotNull);
        expect(state.expectedMove!.san, 'd4');
        expect(state.isLapseAcknowledged, isFalse);

        // Acknowledge lapse
        controller.acknowledgeLapse();
        state = container.read(reviewControllerProvider).requireValue;
        expect(state.feedback, ReviewFeedback.none);
        expect(state.expectedMove, isNull);
        expect(state.isLapseAcknowledged, isTrue);
      },
    );

    test('skip moves current prompt to back of queue', () async {
      final container = createContainer();
      final controller = container.read(reviewControllerProvider.notifier);

      const pgn1 = '1. e4 e5 *';
      const pgn2 = '1. d4 d5 *';

      await controller.importPgnText(pgnText: pgn1, title: 'Open', repertoireSide: Side.white);
      await controller.importPgnText(pgnText: pgn2, title: 'Closed', repertoireSide: Side.white);
      await controller.changeScope(const ReviewScope.all());

      final firstPrompt = container.read(reviewControllerProvider).requireValue.currentPrompt;
      controller.skip();

      final skippedPrompt = container.read(reviewControllerProvider).requireValue.currentPrompt;
      expect(skippedPrompt, isNotNull);
      expect(skippedPrompt!.decision.id, isNot(firstPrompt!.decision.id));
    });

    test('toggleStudyActive updates study status and recalculates all-scope queue', () async {
      final container = createContainer();
      final controller = container.read(reviewControllerProvider.notifier);

      await controller.importPgnText(
        pgnText: '1. e4 e5 *',
        title: 'Open',
        repertoireSide: Side.white,
      );
      final res2 = await controller.importPgnText(
        pgnText: '1. d4 d5 *',
        title: 'Closed',
        repertoireSide: Side.white,
      );

      await controller.changeScope(const ReviewScope.all());
      var state = container.read(reviewControllerProvider).requireValue;
      expect(state.totalDueCount, 2);

      // Suspend the 'Closed' study from daily review pool
      await controller.toggleStudyActive(res2.study.id, false);

      state = container.read(reviewControllerProvider).requireValue;
      expect(state.totalDueCount, 1);
      final updatedStudies = state.studies;
      expect(updatedStudies.firstWhere((s) => s.id == res2.study.id).isActive, isFalse);
    });

    test(
      'renameStudy updates title in-place without setting loading or resetting session',
      () async {
        final container = createContainer();
        final controller = container.read(reviewControllerProvider.notifier);

        final res = await controller.importPgnText(
          pgnText: '1. e4 e5 *',
          title: 'Original Title',
          repertoireSide: Side.white,
        );

        final stateBefore = container.read(reviewControllerProvider).requireValue;
        expect(stateBefore.studies.first.title, 'Original Title');
        final promptBefore = stateBefore.currentPrompt;

        // Rename study
        await controller.renameStudy(res.study.id, 'Renamed Title');

        final asyncState = container.read(reviewControllerProvider);
        expect(asyncState.isLoading, isFalse);
        expect(asyncState.hasValue, isTrue);
        final stateAfter = asyncState.requireValue;
        expect(stateAfter.studies.first.title, 'Renamed Title');
        // Prompt and session remain stable
        expect(stateAfter.currentPrompt?.decision.id, promptBefore?.decision.id);
      },
    );

    test('startPracticeMode trains study without updating SRS review states', () async {
      final container = createContainer();
      final controller = container.read(reviewControllerProvider.notifier);

      final res = await controller.importPgnText(
        pgnText: '1. e4 e5 2. Nf3 Nc6 *',
        title: 'Openings',
        repertoireSide: Side.white,
      );

      // Complete all items in normal review so due count is 0
      await controller.onUserMove(const NormalMove(from: Square.e2, to: Square.e4));
      await Future<void>.delayed(const Duration(milliseconds: 600));
      await controller.onUserMove(const NormalMove(from: Square.g1, to: Square.f3));
      await Future<void>.delayed(const Duration(milliseconds: 600));

      var state = container.read(reviewControllerProvider).requireValue;
      expect(state.totalDueCount, 0);
      expect(state.isComplete, isTrue);

      // Enter Practice Mode (Cram)
      await controller.startPracticeMode(scope: ReviewScope.study(res.study.id));

      state = container.read(reviewControllerProvider).requireValue;
      expect(state.isPracticeMode, isTrue);
      expect(state.isComplete, isFalse);
      expect(state.currentPrompt, isNotNull);

      // Exit Practice Mode
      await controller.exitPracticeMode();
      state = container.read(reviewControllerProvider).requireValue;
      expect(state.isPracticeMode, isFalse);
      expect(state.isComplete, isTrue);
    });

    test('branch transition plays opponent pre-move when line changes', () async {
      final container = createContainer();
      final controller = container.read(reviewControllerProvider.notifier);

      // Repertoire for White with 2 branches:
      // Line 1: 1. e4 e5 2. Nf3
      // Line 2: 1. e4 c5 2. Nf3
      const pgn = '1. e4 e5 (1... c5 2. Nf3) 2. Nf3 *';
      await controller.importPgnText(
        pgnText: pgn,
        title: 'Two Branches',
        repertoireSide: Side.white,
      );

      // Prompt 1: 1. e4 (at initial position, incomingMove is null)
      var state = container.read(reviewControllerProvider).requireValue;
      expect(state.currentPrompt, isNotNull);
      expect(state.currentPrompt!.incomingMove, isNull);

      // User plays 1. e4
      await controller.onUserMove(const NormalMove(from: Square.e2, to: Square.e4));
      // Auto-reply plays 1... e5
      await Future<void>.delayed(const Duration(milliseconds: 700));

      // User plays 2. Nf3 to complete branch 1
      await controller.onUserMove(const NormalMove(from: Square.g1, to: Square.f3));
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Now transitioning to branch 2: Black plays 1... c5, White to play 2. Nf3.
      // Initially, board is at parent position (after 1. e4, before 1... c5)
      state = container.read(reviewControllerProvider).requireValue;
      expect(state.currentPrompt, isNotNull);
      expect(state.currentPrompt!.incomingMove?.san, 'c5');

      // Wait for pre-move animation of 1... c5
      await Future<void>.delayed(const Duration(milliseconds: 400));
      final stateAfterPreMove = container.read(reviewControllerProvider).requireValue;
      expect(stateAfterPreMove.lastMove, const NormalMove(from: Square.c7, to: Square.c5));
    });
  });
}
