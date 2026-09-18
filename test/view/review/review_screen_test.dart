// Copyright (C) 2024 ChessSRS contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:chess_srs/src/domain/domain.dart';
import 'package:chess_srs/src/import/pgn_importer.dart';
import 'package:chess_srs/src/model/study/study_preferences.dart';
import 'package:chess_srs/src/network/http.dart';
import 'package:chess_srs/src/persistence/persistence.dart';
import 'package:chess_srs/src/review/review_service.dart';
import 'package:chess_srs/src/view/analysis/analysis_screen.dart';
import 'package:chess_srs/src/view/review/repertoire_import_dialog.dart';
import 'package:chess_srs/src/view/review/review_screen.dart';
import 'package:chess_srs/src/widgets/game_layout.dart';
import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../binding.dart';
import '../../test_helpers.dart';
import '../../test_provider_scope.dart';

void main() {
  setUpAll(() {
    TestLichessBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('ReviewScreen widget tests', () {
    late Database db;
    late SqliteStudyRepository repo;
    late FixedClock clock;

    setUp(() async {
      await TestLichessBinding.instance.sharedPreferences.clear();
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
      await pumpAsync(tester, 200);

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

    testWidgets('study options sheet opens AnalysisScreen via Analyze Study', (tester) async {
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

      // Open drawer
      await tester.tap(find.byTooltip('Studies & Scope'));
      await pumpAsync(tester);

      // Open study options sheet
      await tester.tap(find.byTooltip('Study options'));
      await pumpAsync(tester);

      // Tap Analyze Study
      await tester.tap(find.text('Analyze Study'));
      await pumpAsync(tester, 200);
      await tester.pumpAndSettle();

      // AnalysisScreen is now opened
      expect(find.byType(AnalysisScreen), findsOneWidget);
    });

    testWidgets('multi-chapter study opens StudyChaptersScreen and navigates to AnalysisScreen', (
      tester,
    ) async {
      const multiChapterPgn = '''
[Event "Chapter 1: Open Games"]
1. e4 e5 *

[Event "Chapter 2: French Defense"]
1. e4 e6 *
''';
      final importResult = importPgn(
        multiChapterPgn,
        studyTitle: 'Multi Chapter Repertoire',
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

      // Open study options sheet
      await tester.tap(find.byTooltip('Study options'));
      await pumpAsync(tester);

      // Tap Analyze Study
      await tester.tap(find.text('Analyze Study'));
      await pumpAsync(tester, 200);
      await tester.pumpAndSettle();

      // StudyChaptersScreen is now opened
      expect(find.byType(StudyChaptersScreen), findsOneWidget);
      expect(find.text('Chapter 1: Open Games'), findsOneWidget);
      expect(find.text('Chapter 2: French Defense'), findsOneWidget);

      // Tap Analyze icon on Chapter 1
      await tester.tap(find.byTooltip('Analyze chapter').first);
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

    testWidgets(
      'board shapes and arrows from PGN comments are withheld before move and revealed on lapse',
      (tester) async {
        final importResult = importPgn(
          '1. e4 {[%cal Gf3e5][%csl Re5] Attacks the center} e5 *',
          studyTitle: 'King Pawn with Shapes',
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

        // Before guessing: GameLayout has NO shapes (anti-spoiler)
        var layout = tester.widget<GameLayout>(find.byType(GameLayout));
        expect(layout.shapes, isEmpty);
        expect(find.text('Attacks the center'), findsNothing);

        // Play incorrect move: d2 -> d4 instead of e2 -> e4
        await playMove(tester, 'd2', 'd4');
        await pumpAsync(tester, 100);

        // After lapse: GameLayout displays the expected move arrow PLUS the comment shapes (arrow and circle)
        layout = tester.widget<GameLayout>(find.byType(GameLayout));
        expect(layout.shapes, isNotNull);
        expect(layout.shapes!.isNotEmpty, isTrue);
        expect(
          layout.shapes!.any((s) => s is Arrow && s.orig == Square.f3 && s.dest == Square.e5),
          isTrue,
        );
        expect(layout.shapes!.any((s) => s is Circle && s.orig == Square.e5), isTrue);

        // Clean comment text without raw [%cal ...] markup
        expect(find.text('Attacks the center'), findsOneWidget);
        expect(find.textContaining('[%cal'), findsNothing);
      },
    );

    testWidgets(
      'when showAnnotations is disabled, board shapes from comments are withheld even after lapse',
      (tester) async {
        final importResult = importPgn(
          '1. e4 {[%cal Gf3e5][%csl Re5] Attacks the center} e5 *',
          studyTitle: 'King Pawn with Shapes Disabled',
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

        // Disable annotations via studyPreferencesProvider
        final element = tester.element(find.byType(ReviewScreen));
        final container = ProviderScope.containerOf(element);
        await container.read(studyPreferencesProvider.notifier).toggleAnnotations();
        await pumpAsync(tester);

        // Play incorrect move: d2 -> d4 instead of e2 -> e4
        await playMove(tester, 'd2', 'd4');
        await pumpAsync(tester, 100);

        // After lapse: only the expected move arrow is present; commentary shapes (Gf3e5, Re5) are NOT added
        final layout = tester.widget<GameLayout>(find.byType(GameLayout));
        expect(layout.shapes, isNotNull);
        expect(
          layout.shapes!.any((s) => s is Arrow && s.orig == Square.f3 && s.dest == Square.e5),
          isFalse,
        );
        expect(layout.shapes!.any((s) => s is Circle && s.orig == Square.e5), isFalse);

        // Text is still present (unless comments are disabled separately)
        expect(find.text('Attacks the center'), findsOneWidget);
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

      // Tap 'Free Practice'
      await tester.tap(find.text('Free Practice'));
      await pumpAsync(tester);

      // Now board is active in practice mode with Practice badge in AppBar!
      expect(find.byType(Chessboard), findsOneWidget);
      expect(find.text('Practice'), findsOneWidget);

      // Exit practice mode via AppBar button
      await tester.tap(find.text('Exit Practice'));
      await pumpAsync(tester);

      // Returned to All Caught Up view
      expect(find.text('All Caught Up!'), findsOneWidget);
    });

    testWidgets('Opening Hubs section appears in drawer and filters review scope', (tester) async {
      const pgn1 = '''
[Opening "Sicilian Defense: Najdorf"]
1. e4 c5 2. Nf3 d6 *
''';
      const pgn2 = '''
[Opening "French Defense: Advance"]
1. e4 e6 2. d4 d5 *
''';
      final import1 = importPgn(pgn1, studyTitle: 'Najdorf PGN', repertoireSide: Side.black);
      final import2 = importPgn(pgn2, studyTitle: 'French PGN', repertoireSide: Side.black);

      await tester.runAsync(() async {
        await repo.saveImportResult(import1);
        await repo.saveImportResult(import2);
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

      // Verify Opening Hubs section exists
      expect(find.text('Opening Hubs'), findsOneWidget);
      expect(find.text('Sicilian Defense'), findsOneWidget);
      expect(find.text('French Defense'), findsOneWidget);

      // Tap 'Sicilian Defense' hub
      await tester.tap(find.text('Sicilian Defense'));
      await pumpAsync(tester);

      // Verify AppBar now shows 'Sicilian Defense' as the active scope
      expect(find.text('Sicilian Defense'), findsOneWidget);
    });

    testWidgets('study options sheet renames and deletes study from drawer', (tester) async {
      final importResult = importPgn(
        '1. e4 e5 *',
        studyTitle: 'Old Title',
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

      // Open study options sheet
      await tester.tap(find.byTooltip('Study options'));
      await pumpAsync(tester);

      // Tap Rename Study
      await tester.tap(find.text('Rename Study'));
      await pumpAsync(tester);

      // Enter new title
      await tester.enterText(find.byType(TextField), 'Renamed Repertoire');
      await tester.tap(find.text('Rename'));
      await pumpAsync(tester);

      // Verify study title updated in drawer
      expect(find.text('Renamed Repertoire'), findsOneWidget);

      // Open study options sheet again to delete
      await tester.tap(find.byTooltip('Study options'));
      await pumpAsync(tester);

      await tester.tap(find.text('Delete Study'));
      await pumpAsync(tester);

      // Tap Delete in confirmation dialog
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await pumpAsync(tester);

      // Study is deleted -> empty state
      expect(find.text('Welcome to ChessSRS'), findsOneWidget);
    });

    testWidgets(
      'correct move with commentary/shapes pauses auto-advancement with Move Explanation and Continue button',
      (tester) async {
        final importResult = importPgn(
          '1. e4 {[%cal Gf3e5][%csl Re5] Attacks the center} e5 *',
          studyTitle: 'King Pawn with Shapes',
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

        // Before move: no shapes or comment
        expect(find.text('Attacks the center'), findsNothing);
        expect(find.text('Move Explanation'), findsNothing);

        // Play correct move: e2 -> e4
        await playMove(tester, 'e2', 'e4');
        await pumpAsync(tester, 100);

        // Auto-advancement paused: shows Move Explanation and Continue button
        expect(find.text('Move Explanation'), findsOneWidget);
        expect(find.text('Attacks the center'), findsOneWidget);
        expect(find.widgetWithText(FilledButton, 'Continue'), findsOneWidget);

        // Shapes are displayed on the board
        final layout = tester.widget<GameLayout>(find.byType(GameLayout));
        expect(layout.shapes, isNotNull);
        expect(
          layout.shapes!.any((s) => s is Arrow && s.orig == Square.f3 && s.dest == Square.e5),
          isTrue,
        );
        expect(layout.shapes!.any((s) => s is Circle && s.orig == Square.e5), isTrue);

        // Tap Continue button
        await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
        await pumpAsync(tester, 700);

        // Queue advances (session caught up)
        expect(find.text('All Caught Up!'), findsOneWidget);
      },
    );

    testWidgets('tapping the board overlay while awaiting advance continues advancement', (
      tester,
    ) async {
      final importResult = importPgn(
        '1. e4 {Important center move} *',
        studyTitle: 'King Pawn Tap Test',
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

      // Play correct move: e2 -> e4
      await playMove(tester, 'e2', 'e4');
      await pumpAsync(tester, 100);

      // Paused awaiting continue
      expect(find.text('Move Explanation'), findsOneWidget);

      // Tap on the chessboard
      await tester.tap(find.byType(Chessboard));
      await pumpAsync(tester, 700);

      // Successfully advanced to completion
      expect(find.text('All Caught Up!'), findsOneWidget);
    });

    testWidgets(
      'quick toggle action in AppBar toggles annotations and updates shapes/comments in real time',
      (tester) async {
        final importResult = importPgn(
          '1. e4 {[%cal Gf3e5] Attacks the center} *',
          studyTitle: 'Quick Toggle Test',
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

        // Initially, annotations are enabled
        expect(find.byTooltip('Hide annotations'), findsOneWidget);

        // Play correct move: e2 -> e4
        await playMove(tester, 'e2', 'e4');
        await pumpAsync(tester, 100);

        // Shapes and commentary are visible
        var layout = tester.widget<GameLayout>(find.byType(GameLayout));
        expect(layout.shapes, isNotEmpty);
        expect(find.text('Attacks the center'), findsOneWidget);

        // Tap the quick toggle button in AppBar
        await tester.tap(find.byTooltip('Hide annotations'));
        await pumpAsync(tester);

        // Tooltip changes to 'Show annotations'
        expect(find.byTooltip('Show annotations'), findsOneWidget);

        // Shapes and comment text are hidden in real time!
        layout = tester.widget<GameLayout>(find.byType(GameLayout));
        expect(layout.shapes, isEmpty);
        expect(find.text('Attacks the center'), findsNothing);

        // Tap the quick toggle again to re-enable
        await tester.tap(find.byTooltip('Show annotations'));
        await pumpAsync(tester);

        // Shapes and comment text reappear
        expect(find.byTooltip('Hide annotations'), findsOneWidget);
        layout = tester.widget<GameLayout>(find.byType(GameLayout));
        expect(layout.shapes, isNotEmpty);
        expect(find.text('Attacks the center'), findsOneWidget);
      },
    );

    testWidgets('ReviewScopeDrawer and All Caught Up view display progress metrics', (
      tester,
    ) async {
      final importResult = importPgn(
        '1. e4 e5 2. Nf3 *',
        studyTitle: 'Progress Test Study',
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

      // Open drawer: before any reviews, 0/2 learned (0%)
      await tester.tap(find.byTooltip('Studies & Scope'));
      await pumpAsync(tester);

      expect(find.text('0/2 learned (0%)'), findsNWidgets(2)); // All Studies & Study tile

      // Close drawer by tapping the All Studies tile
      await tester.tap(find.widgetWithText(ListTile, 'All Studies'));
      await pumpAsync(tester);

      // Play 1. e4 (first move)
      await playMove(tester, 'e2', 'e4');
      await pumpAsync(tester, 700);

      // Play 2. Nf3 (second move)
      await playMove(tester, 'g1', 'f3');
      await pumpAsync(tester, 700);

      // All Caught Up view: shows 2/2 positions mastered (100%) and progress bar
      expect(find.text('All Caught Up!'), findsOneWidget);
      expect(find.textContaining('Next review in 1 day'), findsOneWidget);
      expect(find.text('2/2 positions mastered (100%)'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      // Open drawer again: shows 2/2 learned (100%)
      await tester.tap(find.byTooltip('Studies & Scope'));
      await pumpAsync(tester);

      expect(find.text('2/2 learned (100%)'), findsNWidgets(2));
    });

    testWidgets('RepertoireImportDialog indicates when imported PGN is already up to date', (
      tester,
    ) async {
      const pgn = '1. e4 e5 2. Nf3 *';
      final importResult = importPgn(
        pgn,
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

      // Open drawer and click Import PGN
      await tester.tap(find.byTooltip('Studies & Scope'));
      await pumpAsync(tester);

      await tester.tap(find.text('Import PGN'));
      await pumpAsync(tester);

      expect(find.byType(RepertoireImportDialog), findsOneWidget);

      // Switch to PGN Text / File tab
      await tester.tap(find.text('PGN Text / File'));
      await pumpAsync(tester);

      // Enter same PGN into PGN text field
      await tester.enterText(find.widgetWithText(TextField, 'PGN text'), pgn);
      await tester.tap(find.text('Import and Start Review'));
      await pumpAsync(tester, 600);

      // Dialog is dismissed and info snackbar is shown
      expect(find.byType(RepertoireImportDialog), findsNothing);
      expect(
        find.text('Repertoire "King Pawn Repertoire" is already imported and up to date'),
        findsOneWidget,
      );
    });

    testWidgets('RepertoireImportDialog imports study from Lichess URL', (tester) async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/study/m1AbCd2E.pgn') {
          return http.Response(
            '''
[Event "French Defense: Winawer Variation"]
[Site "https://lichess.org/study/m1AbCd2E"]
1. e4 e6 2. d4 d5 3. Nc3 Bb4 *
''',
            200,
            headers: {'content-type': 'application/x-chess-pgn'},
          );
        }
        return http.Response('Not Found', 404);
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
          lichessClientProvider: lichessClientProvider.overrideWith(
            (ref) => LichessClient(mockClient, ref),
          ),
        },
      );

      await tester.pumpWidget(app);
      await pumpAsync(tester);

      // Open drawer and click Import PGN
      await tester.tap(find.byTooltip('Studies & Scope'));
      await pumpAsync(tester);

      await tester.tap(find.text('Import PGN'));
      await pumpAsync(tester);

      expect(find.byType(RepertoireImportDialog), findsOneWidget);

      // Enter Lichess study URL
      await tester.enterText(
        find.widgetWithText(TextField, 'Lichess Study URL or ID'),
        'https://lichess.org/study/m1AbCd2E',
      );
      await tester.tap(find.text('Fetch & Import from Lichess'));
      await pumpAsync(tester, 600);

      // Dialog is dismissed and success snackbar is shown
      expect(find.byType(RepertoireImportDialog), findsNothing);
      expect(find.textContaining('Imported "French Defense"'), findsOneWidget);
    });

    testWidgets('SRS Diagnostics HUD is hidden by default and displayed when toggled', (
      tester,
    ) async {
      final importResult = importPgn(
        '1. e4 e5 *',
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

      // Vanilla mode: SRS Diagnostics HUD is NOT rendered
      expect(find.text('SRS DIAGNOSTICS'), findsNothing);

      // Toggle srsDiagnostics on
      final element = tester.element(find.byType(ReviewScreen));
      final container = ProviderScope.containerOf(element);
      await container.read(studyPreferencesProvider.notifier).toggleSrsDiagnostics();
      await pumpAsync(tester);

      // Diagnostics HUD is now rendered with live metrics
      expect(find.text('SRS DIAGNOSTICS'), findsOneWidget);
      expect(find.textContaining('R: 100% (New)'), findsOneWidget);
      expect(find.textContaining('D: 5.0/10'), findsOneWidget);
    });

    testWidgets('tapping SRS settings action in AppBar opens SrsSettingsScreen', (tester) async {
      final app = await makeTestProviderScopeApp(tester, home: const ReviewScreen());

      await tester.pumpWidget(app);
      await pumpAsync(tester);

      expect(find.byTooltip('SRS settings'), findsOneWidget);
      await tester.tap(find.byTooltip('SRS settings'));
      await tester.pumpAndSettle();

      expect(find.text('Spaced Repetition (SRS)'), findsOneWidget);
      expect(find.text('Algorithm & Intervals'), findsOneWidget);
    });
  });
}
