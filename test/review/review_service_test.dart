// Copyright (C) 2024 ChessSRS contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:io';

import 'package:chess_srs/src/db/database.dart';
import 'package:chess_srs/src/domain/domain.dart';
import 'package:chess_srs/src/persistence/persistence.dart';
import 'package:chess_srs/src/review/review_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('ReviewService', () {
    late Directory tempDir;
    late String dbPath;
    late FixedClock clock;
    late DateTime now;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('chess_srs_review_service_test_');
      dbPath = p.join(tempDir.path, 'test_service.db');
      now = DateTime.utc(2026, 9, 16, 12, 0, 0);
      clock = FixedClock(now);
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('incremental persistence: moves save state and event without rewriting trees', () async {
      final db = await openAppDatabase(databaseFactoryFfi, dbPath);
      final repo = SqliteStudyRepository(db);

      try {
        final study = Study(id: 's1', title: 'Service Study', createdAt: now, updatedAt: now);
        const root = RepertoireNode(
          id: 'n1',
          fen: 'startfen',
          fenKey: 'startkey',
          children: [
            RepertoireNode(
              id: 'n2',
              fen: 'after_e4',
              fenKey: 'after_e4_key',
              incomingMove: RepertoireMove(from: 'e2', to: 'e4', san: 'e4'),
            ),
          ],
        );
        final chapter = Chapter(
          id: 'c1',
          studyId: 's1',
          sourceOrder: 0,
          title: 'Chapter 1',
          root: root,
          createdAt: now,
        );
        const decision = RepertoireDecision(
          id: 'd1',
          studyId: 's1',
          chapterId: 'c1',
          nodeId: 'n1',
          expectedMoves: [RepertoireMove(from: 'e2', to: 'e4', san: 'e4')],
        );

        await repo.saveStudy(study);
        await repo.saveChapter(chapter);
        await repo.saveDecision(decision);

        final service = ReviewService(repository: repo, clock: clock);

        expect(await service.getDueCount(), 1);

        // Start session
        final session = await service.startSession();
        expect(session.currentPrompt?.decision.id, 'd1');

        // Submit correct move
        final result = await service.submitMove(from: 'e2', to: 'e4');
        expect(result.isCorrect, isTrue);

        // Verify that ReviewState is persisted in DB
        final persistedState = await repo.getReviewState('d1');
        expect(persistedState, isNotNull);
        expect(persistedState!.repetitionCount, 1);
        expect(persistedState.nextDueAt, now.add(const Duration(days: 1)));

        // Verify that ReviewEvent is appended in DB
        final events = await repo.getReviewEvents('d1');
        expect(events.length, 1);
        expect(events.first.result, ReviewResult.correct);
        expect(events.first.decisionId, 'd1');

        // Due count is now 0
        expect(await service.getDueCount(), 0);
      } finally {
        await db.close();
      }
    });

    test('ReviewScope.all excludes inactive studies from dueCount and session', () async {
      final db = await openAppDatabase(databaseFactoryFfi, dbPath);
      final repo = SqliteStudyRepository(db);
      final service = ReviewService(repository: repo, clock: clock);

      try {
        const activeStudy = Study(id: 'active_s', title: 'Active', isActive: true);
        const inactiveStudy = Study(id: 'inactive_s', title: 'Inactive', isActive: false);

        await repo.saveStudy(activeStudy);
        await repo.saveStudy(inactiveStudy);

        final d1 = RepertoireDecision.create(
          studyId: 'active_s',
          chapterId: 'c1',
          nodeId: 'n1',
          expectedMoves: const [RepertoireMove(from: 'e2', to: 'e4', san: 'e4')],
        );
        final d2 = RepertoireDecision.create(
          studyId: 'inactive_s',
          chapterId: 'c2',
          nodeId: 'n2',
          expectedMoves: const [RepertoireMove(from: 'd2', to: 'd4', san: 'd4')],
        );

        await repo.saveDecision(d1);
        await repo.saveDecision(d2);

        // Due count for all should only count the active study decision
        final allDueCount = await service.getDueCount(scope: const ReviewScope.all());
        expect(allDueCount, 1);

        // Explicit study scope still returns the inactive study due count
        final inactiveDueCount = await service.getDueCount(
          scope: const ReviewScope.study('inactive_s'),
        );
        expect(inactiveDueCount, 1);

        // Session for all should only load the active study decision
        final session = await service.startSession(scope: const ReviewScope.all());
        expect(session.remainingDueCount, 1);
        expect(session.currentPrompt?.studyId, 'active_s');
      } finally {
        await db.close();
      }
    });
  });
}
