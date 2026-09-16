// Copyright (C) 2024 ChessSRS contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:chess_srs/src/domain/domain.dart';
import 'package:chess_srs/src/import/pgn_importer.dart';
import 'package:chess_srs/src/persistence/persistence.dart';
import 'package:chess_srs/src/review/review_service.dart';
import 'package:chess_srs/src/view/analysis/analysis_screen.dart';
import 'package:chess_srs/src/view/review/repertoire_import_dialog.dart';
import 'package:chess_srs/src/view/review/review_screen.dart';
import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../test_helpers.dart';
import '../../test_provider_scope.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('ReviewScreen widget tests', () {
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

    Future<void> pumpAsync(WidgetTester tester, [int ms = 80]) async {
      await tester.runAsync(() async {
        await Future<void>.delayed(Duration(milliseconds: ms));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('shows first launch empty state when no studies exist', (tester) async {
      final app = await makeTestProviderScopeApp(
        tester,
        home: const ReviewScreen(),
        overrides: {
          srsStudyRepositoryProvider: srsStudyRepositoryProvider.overrideWith((ref) => repo),
          clockProvider: clockProvider.overrideWithValue(clock),
          reviewServiceProvider: reviewServiceProvider.overrideWith(
            (ref) => ReviewService(repository: repo, clock: clock),
          ),
        },
      );

      await tester.pumpWidget(app);
      await pumpAsync(tester);

      expect(find.text('Welcome to ChessSRS'), findsOneWidget);
      expect(find.text('Import Repertoire PGN'), findsWidgets);
    });

    testWidgets('tapping import button opens RepertoireImportDialog', (tester) async {
      final app = await makeTestProviderScopeApp(
        tester,
        home: const ReviewScreen(),
        overrides: {
          srsStudyRepositoryProvider: srsStudyRepositoryProvider.overrideWith((ref) => repo),
          clockProvider: clockProvider.overrideWithValue(clock),
          reviewServiceProvider: reviewServiceProvider.overrideWith(
            (ref) => ReviewService(repository: repo, clock: clock),
          ),
        },
      );

      await tester.pumpWidget(app);
      await pumpAsync(tester);

      await tester.tap(find.text('Import Repertoire PGN').first);
      await tester.pump();
      await pumpAsync(tester);

      expect(find.byType(RepertoireImportDialog), findsOneWidget);
    });

    testWidgets('renders active board and handles moves when studies exist', (tester) async {
      // Setup a study with 1. e4 e5 2. Nf3
      final importResult = importPgn(
        '1. e4 e5 2. Nf3 *',
        studyTitle: 'King Pawn Repertoire',
        repertoireSide: Side.white,
      );
      await tester.runAsync(() async {
        await repo.saveImportResult(importResult);
      });

      final app = await makeTestProviderScopeApp(
        tester,
        home: const ReviewScreen(),
        overrides: {
          srsStudyRepositoryProvider: srsStudyRepositoryProvider.overrideWith((ref) => repo),
          clockProvider: clockProvider.overrideWithValue(clock),
          reviewServiceProvider: reviewServiceProvider.overrideWith(
            (ref) => ReviewService(repository: repo, clock: clock),
          ),
        },
      );

      await tester.pumpWidget(app);
      await pumpAsync(tester);

      // Board is rendered with Chessboard
      expect(find.byType(Chessboard), findsOneWidget);
      expect(find.text('All Studies'), findsOneWidget);

      // Play correct move: e2 -> e4
      await playMove(tester, 'e2', 'e4');

      // Wait for move pacing (user move -> pause -> opponent reply 1... e5 -> pause)
      await pumpAsync(tester, 700);

      // Next due move is 2. Nf3 (opponent move e5 was auto-played)
      await playMove(tester, 'g1', 'f3');
      await pumpAsync(tester, 700);

      // Session is now complete (0 due)
      expect(find.text('All Caught Up!'), findsOneWidget);
    });

    testWidgets('displays lapse feedback and allows user to reguess on the board', (tester) async {
      final importResult = importPgn(
        '1. d4 d5 *',
        studyTitle: 'Queen Pawn',
        repertoireSide: Side.white,
      );
      await tester.runAsync(() async {
        await repo.saveImportResult(importResult);
      });

      final app = await makeTestProviderScopeApp(
        tester,
        home: const ReviewScreen(),
        overrides: {
          srsStudyRepositoryProvider: srsStudyRepositoryProvider.overrideWith((ref) => repo),
          clockProvider: clockProvider.overrideWithValue(clock),
          reviewServiceProvider: reviewServiceProvider.overrideWith(
            (ref) => ReviewService(repository: repo, clock: clock),
          ),
        },
      );

      await tester.pumpWidget(app);
      await pumpAsync(tester);

      // Play incorrect move: e2 -> e4 instead of d2 -> d4
      await playMove(tester, 'e2', 'e4');
      await pumpAsync(tester, 100);

      // Shows lapse feedback banner
      expect(find.textContaining('Repertoire was d4'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);

      // Reguess on the board by playing the correct repertoire move d2 -> d4
      await playMove(tester, 'd2', 'd4');
      await pumpAsync(tester, 700);

      // Re-prompted for the failed item (re-queued for practice)
      expect(find.byType(Chessboard), findsOneWidget);
      expect(find.text('Your move (White)'), findsOneWidget);

      // Play 1. d4 successfully on the re-test
      await playMove(tester, 'd2', 'd4');
      await pumpAsync(tester, 700);

      // Session is now complete (0 due)
      expect(find.text('All Caught Up!'), findsOneWidget);
    });

    testWidgets('tapping explore moves button opens AnalysisScreen with study PGN', (tester) async {
      final importResult = importPgn(
        '1. e4 e5 2. Nf3 Nc6 *',
        studyTitle: 'King Pawn Repertoire',
        repertoireSide: Side.white,
      );
      await tester.runAsync(() async {
        await repo.saveImportResult(importResult);
      });

      final app = await makeTestProviderScopeApp(
        tester,
        home: const ReviewScreen(),
        overrides: {
          srsStudyRepositoryProvider: srsStudyRepositoryProvider.overrideWith((ref) => repo),
          clockProvider: clockProvider.overrideWithValue(clock),
          reviewServiceProvider: reviewServiceProvider.overrideWith(
            (ref) => ReviewService(repository: repo, clock: clock),
          ),
        },
      );

      await tester.pumpWidget(app);
      await pumpAsync(tester);

      // Find the explore action in the AppBar
      final exploreButton = find.byTooltip('Explore moves');
      expect(exploreButton, findsOneWidget);

      await tester.tap(exploreButton);
      await pumpAsync(tester, 200);
      await tester.pumpAndSettle();

      // AnalysisScreen is now opened
      expect(find.byType(AnalysisScreen), findsOneWidget);
    });

    testWidgets(
      'comments are withheld during active recall to prevent move spoilers and revealed on lapse',
      (tester) async {
        final importResult = importPgn(
          '1. e4 {Best by test} 1... e5 2. Nf3 {Attacks the e5 pawn} *',
          studyTitle: 'King Pawn with Comments',
          repertoireSide: Side.white,
        );
        await tester.runAsync(() async {
          await repo.saveImportResult(importResult);
        });

        final app = await makeTestProviderScopeApp(
          tester,
          home: const ReviewScreen(),
          overrides: {
            srsStudyRepositoryProvider: srsStudyRepositoryProvider.overrideWith((ref) => repo),
            clockProvider: clockProvider.overrideWithValue(clock),
            reviewServiceProvider: reviewServiceProvider.overrideWith(
              (ref) => ReviewService(repository: repo, clock: clock),
            ),
          },
        );

        await tester.pumpWidget(app);
        await pumpAsync(tester);

        // Verify comment is NOT shown before guessing (anti-spoiler)
        expect(find.text('Best by test'), findsNothing);

        // Play incorrect move: d2 -> d4 instead of e2 -> e4
        await playMove(tester, 'd2', 'd4');
        await pumpAsync(tester, 100);

        // Now the comment is revealed as explanation
        expect(find.text('Best by test'), findsOneWidget);
      },
    );

    testWidgets('study active toggle suspends and activates study from review pool in drawer', (
      tester,
    ) async {
      final importResult = importPgn(
        '1. e4 e5 *',
        studyTitle: 'Active Study',
        repertoireSide: Side.white,
      );
      await tester.runAsync(() async {
        await repo.saveImportResult(importResult);
      });

      final app = await makeTestProviderScopeApp(
        tester,
        home: const ReviewScreen(),
        overrides: {
          srsStudyRepositoryProvider: srsStudyRepositoryProvider.overrideWith((ref) => repo),
          clockProvider: clockProvider.overrideWithValue(clock),
          reviewServiceProvider: reviewServiceProvider.overrideWith(
            (ref) => ReviewService(repository: repo, clock: clock),
          ),
        },
      );

      await tester.pumpWidget(app);
      await pumpAsync(tester);

      // Open drawer
      await tester.tap(find.byTooltip('Studies & Scope'));
      await pumpAsync(tester);

      // Find toggle icon in drawer
      final toggleButton = find.byTooltip('Active in review pool (tap to suspend)');
      expect(toggleButton, findsOneWidget);

      // Tap toggle to suspend study
      await tester.tap(toggleButton);
      await pumpAsync(tester);

      // Verify study toggle icon updated to suspended state
      expect(find.byTooltip('Suspended from review pool (tap to activate)'), findsOneWidget);
    });

    testWidgets('tapping Rehearse Moves enters cram mode when 0 items are due', (tester) async {
      final importResult = importPgn(
        '1. e4 e5 2. Nf3 Nc6 *',
        studyTitle: 'Rehearse Study',
        repertoireSide: Side.white,
      );
      await tester.runAsync(() async {
        await repo.saveImportResult(importResult);
        // Mark all decisions as already learned (due in future)
        for (final d in importResult.decisions) {
          await repo.saveReviewState(
            ReviewState(decisionId: d.id, nextDueAt: DateTime.utc(2026, 10, 1), repetitionCount: 3),
          );
        }
      });

      final app = await makeTestProviderScopeApp(
        tester,
        home: const ReviewScreen(),
        overrides: {
          srsStudyRepositoryProvider: srsStudyRepositoryProvider.overrideWith((ref) => repo),
          clockProvider: clockProvider.overrideWithValue(clock),
          reviewServiceProvider: reviewServiceProvider.overrideWith(
            (ref) => ReviewService(repository: repo, clock: clock),
          ),
        },
      );

      await tester.pumpWidget(app);
      await pumpAsync(tester);

      // Initially 0 items due -> shows All Caught Up view
      expect(find.text('All Caught Up!'), findsOneWidget);

      // Tap 'Rehearse Moves (Cram)'
      await tester.tap(find.text('Rehearse Moves (Cram)'));
      await pumpAsync(tester);

      // Now board is active in cram mode with Cram badge in AppBar!
      expect(find.byType(Chessboard), findsOneWidget);
      expect(find.text('Cram'), findsOneWidget);

      // Exit rehearsal mode via AppBar button
      await tester.tap(find.byTooltip('Exit Rehearsal'));
      await pumpAsync(tester);

      // Returned to All Caught Up view
      expect(find.text('All Caught Up!'), findsOneWidget);
    });
  });
}
