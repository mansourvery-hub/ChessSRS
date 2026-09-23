// Copyright (C) 2024 ChessSRS contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:chess_srs/src/domain/domain.dart';
import 'package:chess_srs/src/import/pgn_importer.dart';
import 'package:chess_srs/src/review/review_controller.dart';
import 'package:chess_srs/src/view/analysis/analysis_screen.dart';
import 'package:chess_srs/src/view/review/study_chapters_screen.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../binding.dart';
import '../../test_provider_scope.dart';

void main() {
  setUpAll(() {
    TestLichessBinding.ensureInitialized();
  });

  setUp(() async {
    await TestLichessBinding.instance.sharedPreferences.clear();
  });

  group('StudyChaptersScreen', () {
    testWidgets(
      'explorer mode: renders chapters and tapping ListTile navigates to AnalysisScreen',
      (tester) async {
        final study = Study.create(title: 'My Sicilian Repertoire');
        final importRes = importPgn('1. e4 c5 2. Nf3 d6 *', studyTitle: 'My Sicilian Repertoire');
        final ch1 = importRes.chapters.first.copyWith(
          title: 'Open Sicilian',
          opening: 'Sicilian Defense',
          orientation: Side.black,
        );
        final ch2 = Chapter.create(
          studyId: study.id,
          title: 'Closed Sicilian',
          sourceOrder: 1,
          orientation: Side.black,
        );

        final app = await makeTestProviderScopeApp(
          tester,
          home: StudyChaptersScreen(study: study, chapters: [ch1, ch2], isExplorerMode: true),
        );

        await tester.pumpWidget(app);
        await tester.pump();

        expect(find.text('My Sicilian Repertoire'), findsOneWidget);
        expect(find.text('Sicilian Defense'), findsOneWidget);
        expect(find.text('Open Sicilian'), findsOneWidget);
        expect(find.text('Closed Sicilian'), findsOneWidget);

        // Verify tapping the chapter 1 ListTile in explorer mode navigates to AnalysisScreen
        await tester.tap(find.text('Open Sicilian'));
        await tester.pumpAndSettle();

        expect(find.byType(AnalysisScreen), findsOneWidget);
      },
    );

    testWidgets('scope mode: tapping ListTile changes scope to chapter and pops', (tester) async {
      final study = Study.create(title: 'Sicilian Defense');
      final ch1 = Chapter.create(studyId: study.id, title: 'Open Sicilian', sourceOrder: 0);

      ReviewScope? capturedScope;
      final app = await makeTestProviderScopeApp(
        tester,
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              StudyChaptersScreen.buildRoute(study: study, chapters: [ch1], isExplorerMode: false),
            ),
            child: const Text('Open Chapters'),
          ),
        ),
        overrides: {
          reviewControllerProvider: reviewControllerProvider.overrideWith(
            () => _MockReviewController((scope) => capturedScope = scope),
          ),
        },
      );

      await tester.pumpWidget(app);
      await tester.tap(find.text('Open Chapters'));
      await tester.pumpAndSettle();

      expect(find.text('Open Sicilian'), findsOneWidget);

      // Tapping in scope mode should change scope and pop screen
      await tester.tap(find.text('Open Sicilian'));
      await tester.pumpAndSettle();

      expect(find.byType(StudyChaptersScreen), findsNothing);
      expect(capturedScope?.chapterId, equals(ch1.id));
    });
  });
}

class _MockReviewController extends ReviewController {
  _MockReviewController(this.onChangeScope);
  final void Function(ReviewScope scope) onChangeScope;

  @override
  Future<ReviewScreenState> build() async {
    return const ReviewScreenState(
      studies: [],
      scope: ReviewScope.all(),
      totalDueCount: 0,
      studyDueCounts: {},
    );
  }

  @override
  Future<void> changeScope(ReviewScope scope) async {
    onChangeScope(scope);
  }
}
