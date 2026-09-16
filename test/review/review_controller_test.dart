// Copyright (C) 2024 ChessSRS contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:chess_srs/src/domain/domain.dart';
import 'package:chess_srs/src/persistence/persistence.dart';
import 'package:chess_srs/src/review/review_controller.dart';
import 'package:chess_srs/src/review/review_service.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
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
      expect(state.totalDueCount, 2);
      expect(state.currentPrompt, isNotNull);
      expect(state.boardOrientation, Side.black);
      expect(state.boardPosition, isNotNull);
      expect(state.boardPosition!.turn, Side.black);
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
      expect(state.feedback, ReviewFeedback.correct);
      expect(state.totalDueCount, 1);
      // Auto-traversal played 1... e5, so next prompt is for 2. Nf3
      expect(state.currentPrompt, isNotNull);
      expect(state.currentPrompt!.expectedMoves.first.san, 'Nf3');
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

      final firstPrompt = container.read(reviewControllerProvider).requireValue.currentPrompt;
      controller.skip();

      final skippedPrompt = container.read(reviewControllerProvider).requireValue.currentPrompt;
      expect(skippedPrompt, isNotNull);
      expect(skippedPrompt!.decision.id, isNot(firstPrompt!.decision.id));
    });
  });
}
