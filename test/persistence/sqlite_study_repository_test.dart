// Copyright (C) 2024 ChessSRS contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:io';

import 'package:chess_srs/src/db/database.dart';
import 'package:chess_srs/src/domain/domain.dart';
import 'package:chess_srs/src/persistence/persistence.dart';
import 'package:dartchess/dartchess.dart' show Side;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('SqliteStudyRepository', () {
    late Directory tempDir;
    late String dbPath;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('chess_srs_test_');
      dbPath = p.join(tempDir.path, 'test_persistence.db');
    });

    tearDown(() {
      try {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    });

    test('durability across restart (close and reopen)', () async {
      // 1. Open database and populate data
      var db = await openAppDatabase(databaseFactoryFfi, dbPath);
      var repo = SqliteStudyRepository(db);

      final now = DateTime.utc(2026, 9, 16, 12, 0, 0);
      final study = Study(
        id: 'study-kid-1',
        title: "King's Indian Defence",
        createdAt: now,
        updatedAt: now,
      );

      const rootNode = RepertoireNode(
        id: 'node-root',
        fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
        fenKey: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq -',
        children: [
          RepertoireNode(
            id: 'node-d4',
            fen: 'rnbqkbnr/pppppppp/8/8/3P4/8/PPP1PPPP/RNBQKBNR b KQkq d3 0 1',
            fenKey: 'rnbqkbnr/pppppppp/8/8/3P4/8/PPP1PPPP/RNBQKBNR b KQkq -',
            incomingMove: RepertoireMove(from: 'd2', to: 'd4', san: 'd4'),
            children: [
              RepertoireNode(
                id: 'node-nf6',
                fen: 'rnbqkb1r/pppppppp/5n2/8/3P4/8/PPP1PPPP/RNBQKBNR w KQkq - 1 2',
                fenKey: 'rnbqkb1r/pppppppp/5n2/8/3P4/8/PPP1PPPP/RNBQKBNR w KQkq -',
                incomingMove: RepertoireMove(from: 'g8', to: 'f6', san: 'Nf6'),
                comment: 'Main reply against 1. d4',
              ),
            ],
          ),
        ],
      );

      final chapter = Chapter(
        id: 'chapter-1',
        studyId: study.id,
        sourceOrder: 0,
        title: 'Main Line',
        startingFen: rootNode.fen,
        root: rootNode,
        createdAt: now,
      );

      const decision = RepertoireDecision(
        id: 'decision-1',
        studyId: 'study-kid-1',
        chapterId: 'chapter-1',
        nodeId: 'node-d4',
        expectedMoves: [RepertoireMove(from: 'g8', to: 'f6', san: 'Nf6')],
      );

      final reviewState = ReviewState(
        decisionId: decision.id,
        firstReviewedAt: now,
        lastReviewedAt: now,
        nextDueAt: now.add(const Duration(days: 1)),
        repetitionCount: 1,
        lapseCount: 0,
        stability: 1.0,
      );

      final reviewEvent = ReviewEvent(
        decisionId: decision.id,
        when: now,
        result: ReviewResult.correct,
        oldState: ReviewState.initial(decisionId: decision.id),
        newState: reviewState,
      );

      await repo.saveStudy(study);
      await repo.saveChapter(chapter);
      await repo.saveDecision(decision);
      await repo.saveReviewState(reviewState);
      await repo.saveReviewEvent(reviewEvent);

      // 2. Close the database
      await db.close();

      // 3. Reopen from disk
      db = await openAppDatabase(databaseFactoryFfi, dbPath);
      repo = SqliteStudyRepository(db);

      try {
        // 4. Verify Study
        final retrievedStudy = await repo.getStudy(study.id);
        expect(retrievedStudy, isNotNull);
        expect(retrievedStudy!.id, study.id);
        expect(retrievedStudy.title, study.title);
        expect(retrievedStudy.createdAt, study.createdAt);

        final allStudies = await repo.getAllStudies();
        expect(allStudies.length, 1);
        expect(allStudies.first.id, study.id);

        // 5. Verify Chapter & Variation Tree
        final retrievedChapter = await repo.getChapter(chapter.id);
        expect(retrievedChapter, isNotNull);
        expect(retrievedChapter!.id, chapter.id);
        expect(retrievedChapter.title, chapter.title);
        expect(retrievedChapter.root, isNotNull);

        final retrievedRoot = retrievedChapter.root!;
        expect(retrievedRoot.id, rootNode.id);
        expect(retrievedRoot.children.length, 1);

        final childD4 = retrievedRoot.children.first;
        expect(childD4.incomingMove?.san, 'd4');
        expect(childD4.children.length, 1);

        final childNf6 = childD4.children.first;
        expect(childNf6.incomingMove?.san, 'Nf6');
        expect(childNf6.comment, 'Main reply against 1. d4');

        // 6. Verify Decision
        final retrievedDecision = await repo.getDecision(decision.id);
        expect(retrievedDecision, isNotNull);
        expect(retrievedDecision!.id, decision.id);
        expect(retrievedDecision.expectedMoves.first.san, 'Nf6');

        final decisionsByStudy = await repo.getDecisionsByStudy(study.id);
        expect(decisionsByStudy.length, 1);
        expect(decisionsByStudy.first.id, decision.id);

        // 7. Verify ReviewState
        final retrievedState = await repo.getReviewState(decision.id);
        expect(retrievedState, isNotNull);
        expect(retrievedState!.decisionId, decision.id);
        expect(retrievedState.repetitionCount, 1);
        expect(retrievedState.lapseCount, 0);
        expect(retrievedState.stability, 1.0);
        expect(retrievedState.nextDueAt, now.add(const Duration(days: 1)));

        // 8. Verify ReviewEvent
        final events = await repo.getReviewEvents(decision.id);
        expect(events.length, 1);
        expect(events.first.decisionId, decision.id);
        expect(events.first.result, ReviewResult.correct);
        expect(events.first.oldState.repetitionCount, 0);
        expect(events.first.newState.repetitionCount, 1);
      } finally {
        await db.close();
      }
    });

    test(
      'incremental persistence: review answer touches only review_state and review_event',
      () async {
        final db = await openAppDatabase(databaseFactoryFfi, dbPath);
        final repo = SqliteStudyRepository(db);

        try {
          final now = DateTime.utc(2026, 9, 16, 12, 0, 0);
          final study = Study(id: 'study-1', title: 'Test Study', createdAt: now, updatedAt: now);
          final chapter = Chapter(
            id: 'ch-1',
            studyId: study.id,
            sourceOrder: 0,
            title: 'Ch 1',
            root: const RepertoireNode(id: 'r', fen: 'startfen', fenKey: 'startkey'),
          );
          const decision = RepertoireDecision(
            id: 'dec-1',
            studyId: 'study-1',
            chapterId: 'ch-1',
            nodeId: 'r',
            expectedMoves: [RepertoireMove(from: 'e2', to: 'e4')],
          );

          await repo.saveStudy(study);
          await repo.saveChapter(chapter);
          await repo.saveDecision(decision);

          // Fetch initial chapter and study row state
          final chapterBefore = await db.query(
            kTableSrsChapter,
            where: 'id = ?',
            whereArgs: ['ch-1'],
          );
          final studyBefore = await db.query(
            kTableSrsStudy,
            where: 'id = ?',
            whereArgs: ['study-1'],
          );

          // Incremental review update
          final nextState = ReviewState(
            decisionId: decision.id,
            firstReviewedAt: now,
            lastReviewedAt: now,
            nextDueAt: now.add(const Duration(days: 1)),
            repetitionCount: 1,
            stability: 1.0,
          );
          final event = ReviewEvent(
            decisionId: decision.id,
            when: now,
            result: ReviewResult.correct,
            oldState: ReviewState.initial(decisionId: decision.id),
            newState: nextState,
          );

          await repo.saveReviewState(nextState);
          await repo.saveReviewEvent(event);

          // Verify that srs_chapter and srs_study rows were NOT touched
          final chapterAfter = await db.query(
            kTableSrsChapter,
            where: 'id = ?',
            whereArgs: ['ch-1'],
          );
          final studyAfter = await db.query(
            kTableSrsStudy,
            where: 'id = ?',
            whereArgs: ['study-1'],
          );

          expect(chapterAfter, equals(chapterBefore));
          expect(studyAfter, equals(studyBefore));

          // Verify that srs_review_state and srs_review_event have the new data
          final stateRows = await db.query(kTableSrsReviewState);
          expect(stateRows.length, 1);
          expect(stateRows.first['decisionId'], 'dec-1');

          final eventRows = await db.query(kTableSrsReviewEvent);
          expect(eventRows.length, 1);
          expect(eventRows.first['decisionId'], 'dec-1');
        } finally {
          await db.close();
        }
      },
    );

    test('getDueReviewStates retrieves past and unreviewed items ordered by due date', () async {
      final db = await openAppDatabase(databaseFactoryFfi, dbPath);
      final repo = SqliteStudyRepository(db);

      try {
        final now = DateTime.utc(2026, 9, 16, 12, 0, 0);

        const unreviewed = ReviewState(decisionId: 'unreviewed');
        final overdue = ReviewState(
          decisionId: 'overdue',
          nextDueAt: now.subtract(const Duration(hours: 2)),
          repetitionCount: 2,
        );
        final dueNow = ReviewState(decisionId: 'dueNow', nextDueAt: now, repetitionCount: 1);
        final future = ReviewState(
          decisionId: 'future',
          nextDueAt: now.add(const Duration(days: 3)),
          repetitionCount: 3,
        );

        await repo.saveReviewStates([future, overdue, unreviewed, dueNow]);

        final dueItems = await repo.getDueReviewStates(now);
        final dueIds = dueItems.map((s) => s.decisionId).toList();

        // Should include unreviewed, overdue, and dueNow, but NOT future
        expect(dueIds, containsAll(['unreviewed', 'overdue', 'dueNow']));
        expect(dueIds, isNot(contains('future')));

        // Null nextDueAt comes first in SQLite ASC order
        expect(dueItems.first.decisionId, 'unreviewed');
        expect(dueItems[1].decisionId, 'overdue');
        expect(dueItems[2].decisionId, 'dueNow');
      } finally {
        await db.close();
      }
    });

    test('deleteStudy cascades and cleans up chapters, decisions, states, and events', () async {
      final db = await openAppDatabase(databaseFactoryFfi, dbPath);
      final repo = SqliteStudyRepository(db);

      try {
        final now = DateTime.utc(2026, 9, 16, 12, 0, 0);
        final study = Study(id: 'study-delete', title: 'To Delete', createdAt: now, updatedAt: now);
        final chapter = Chapter(id: 'ch-del', studyId: study.id, sourceOrder: 0);
        const decision = RepertoireDecision(
          id: 'dec-del',
          studyId: 'study-delete',
          chapterId: 'ch-del',
          nodeId: 'n1',
          expectedMoves: [],
        );
        const state = ReviewState(decisionId: 'dec-del');
        final event = ReviewEvent(
          decisionId: 'dec-del',
          when: now,
          result: ReviewResult.correct,
          oldState: state,
          newState: state,
        );

        await repo.saveStudy(study);
        await repo.saveChapter(chapter);
        await repo.saveDecision(decision);
        await repo.saveReviewState(state);
        await repo.saveReviewEvent(event);

        expect(await repo.getStudy(study.id), isNotNull);
        expect(await repo.getChapter(chapter.id), isNotNull);
        expect(await repo.getDecision(decision.id), isNotNull);
        expect(await repo.getReviewState(decision.id), isNotNull);
        expect((await repo.getReviewEvents(decision.id)).length, 1);

        await repo.deleteStudy(study.id);

        expect(await repo.getStudy(study.id), isNull);
        expect(await repo.getChapter(chapter.id), isNull);
        expect(await repo.getDecision(decision.id), isNull);
        expect(await repo.getReviewState(decision.id), isNull);
        expect(await repo.getReviewEvents(decision.id), isEmpty);
      } finally {
        await db.close();
      }
    });

    test('savePositionTree updates tree independently of chapter metadata', () async {
      final db = await openAppDatabase(databaseFactoryFfi, dbPath);
      final repo = SqliteStudyRepository(db);

      try {
        final now = DateTime.utc(2026, 9, 16, 12, 0, 0);
        final study = Study(id: 'study-tree', title: 'Tree Study', createdAt: now, updatedAt: now);
        final chapter = Chapter(
          id: 'ch-tree',
          studyId: study.id,
          sourceOrder: 1,
          title: 'Original Title',
          createdAt: now,
        );

        await repo.saveStudy(study);
        await repo.saveChapter(chapter);

        expect(await repo.getPositionTree(chapter.id), isNull);

        const tree = RepertoireNode(
          id: 'node-root-new',
          fen: 'startpos',
          fenKey: 'startkey',
          comment: 'Root comment',
        );

        await repo.savePositionTree(chapter.id, tree);

        final loadedTree = await repo.getPositionTree(chapter.id);
        expect(loadedTree, isNotNull);
        expect(loadedTree!.id, 'node-root-new');
        expect(loadedTree.comment, 'Root comment');

        // Chapter title and metadata remained intact
        final updatedChapter = await repo.getChapter(chapter.id);
        expect(updatedChapter!.title, 'Original Title');
        expect(updatedChapter.sourceOrder, 1);
      } finally {
        await db.close();
      }
    });

    test('study isActive toggle and persistence', () async {
      final db = await openAppDatabase(databaseFactoryFfi, dbPath);
      final repo = SqliteStudyRepository(db);

      try {
        const study1 = Study(id: 's1', title: 'Active Study', isActive: true);
        const study2 = Study(id: 's2', title: 'Inactive Study', isActive: false);

        await repo.saveStudy(study1);
        await repo.saveStudy(study2);

        expect((await repo.getAllStudies()).length, 2);
        final active = await repo.getActiveStudies();
        expect(active.length, 1);
        expect(active.first.id, 's1');

        // Toggle s1 to inactive and s2 to active
        await repo.updateStudyActive('s1', false);
        await repo.updateStudyActive('s2', true);

        final updatedActive = await repo.getActiveStudies();
        expect(updatedActive.length, 1);
        expect(updatedActive.first.id, 's2');

        // Restart durability: reopen database from disk
        await db.close();
        final reopenedDb = await openAppDatabase(databaseFactoryFfi, dbPath);
        final reopenedRepo = SqliteStudyRepository(reopenedDb);
        try {
          final loadedS1 = await reopenedRepo.getStudy('s1');
          final loadedS2 = await reopenedRepo.getStudy('s2');
          expect(loadedS1!.isActive, isFalse);
          expect(loadedS2!.isActive, isTrue);
        } finally {
          await reopenedDb.close();
        }
      } finally {
        if (db.isOpen) await db.close();
      }
    });

    test('getChapterOpenings retrieves map of chapter IDs to opening families', () async {
      final db = await openAppDatabase(databaseFactoryFfi, dbPath);
      final repo = SqliteStudyRepository(db);

      try {
        const study = Study(id: 's1', title: 'Openings Study');
        await repo.saveStudy(study);

        final ch1 = Chapter.create(studyId: 's1', sourceOrder: 0, opening: 'Ruy Lopez');
        final ch2 = Chapter.create(studyId: 's1', sourceOrder: 1, opening: 'Sicilian Defense');
        final ch3 = Chapter.create(studyId: 's1', sourceOrder: 2, opening: null);

        await repo.saveChapters([ch1, ch2, ch3]);

        final openings = await repo.getChapterOpenings();
        expect(openings[ch1.id], 'Ruy Lopez');
        expect(openings[ch2.id], 'Sicilian Defense');
        expect(openings[ch3.id], isNull);
      } finally {
        await db.close();
      }
    });

    test('getStudyByPgnHash retrieves study by SHA-256 fingerprint', () async {
      final db = await openAppDatabase(databaseFactoryFfi, dbPath);
      final repo = SqliteStudyRepository(db);

      try {
        const hash = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';
        const study = Study(id: 's_hashed', title: 'Hashed Study', pgnHash: hash);
        await repo.saveStudy(study);

        final found = await repo.getStudyByPgnHash(hash);
        expect(found, isNotNull);
        expect(found!.id, 's_hashed');
        expect(found.title, 'Hashed Study');
        expect(found.pgnHash, hash);

        final notFound = await repo.getStudyByPgnHash('non_existent_hash');
        expect(notFound, isNull);
      } finally {
        await db.close();
      }
    });

    test('getReviewStatesByDecisions retrieves only review states for specified IDs', () async {
      final db = await openAppDatabase(databaseFactoryFfi, dbPath);
      final repo = SqliteStudyRepository(db);

      try {
        const s1 = ReviewState(decisionId: 'dec-1', repetitionCount: 1);
        const s2 = ReviewState(decisionId: 'dec-2', repetitionCount: 2);
        const s3 = ReviewState(decisionId: 'dec-3', repetitionCount: 3);
        await repo.saveReviewStates([s1, s2, s3]);

        final queried = await repo.getReviewStatesByDecisions(['dec-1', 'dec-3']);
        expect(queried.length, 2);
        expect(queried.map((s) => s.decisionId).toSet(), equals({'dec-1', 'dec-3'}));

        final emptyQuery = await repo.getReviewStatesByDecisions([]);
        expect(emptyQuery, isEmpty);
      } finally {
        await db.close();
      }
    });

    test(
      'savePositionKnowledgeState and getPositionKnowledgeState roundtrips canonical state',
      () async {
        final db = await openAppDatabase(databaseFactoryFfi, dbPath);
        final repo = SqliteStudyRepository(db);

        try {
          final now = DateTime.utc(2026, 9, 18, 12);
          final kState = PositionKnowledgeState(
            canonicalId: 'canonical_test_1',
            firstReviewedAt: now,
            lastReviewedAt: now,
            nextDueAt: now.add(const Duration(days: 3)),
            repetitionCount: 4,
            lapseCount: 1,
            stability: 259200000.0,
            difficulty: 4.8,
            latencyEmaMs: 1420.5,
            latencySampleCount: 5,
          );

          await repo.savePositionKnowledgeState(kState);

          final loaded = await repo.getPositionKnowledgeState('canonical_test_1');
          expect(loaded, isNotNull);
          expect(loaded!.canonicalId, 'canonical_test_1');
          expect(loaded.repetitionCount, 4);
          expect(loaded.lapseCount, 1);
          expect(loaded.stability, 259200000.0);
          expect(loaded.difficulty, 4.8);
          expect(loaded.latencyEmaMs, 1420.5);
          expect(loaded.latencySampleCount, 5);

          // Also synchronized to legacy review_state
          final legacy = await repo.getReviewState('canonical_test_1');
          expect(legacy, isNotNull);
          expect(legacy!.repetitionCount, 4);
        } finally {
          await db.close();
        }
      },
    );

    test('decision canonicalStateId is persisted and retrieved', () async {
      final db = await openAppDatabase(databaseFactoryFfi, dbPath);
      final repo = SqliteStudyRepository(db);

      try {
        const study = Study(id: 's_canon', title: 'Canonical Study');
        await repo.saveStudy(study);
        final ch = Chapter.create(studyId: 's_canon', sourceOrder: 0);
        await repo.saveChapter(ch);

        const dec = RepertoireDecision(
          id: 'dec_canon_1',
          studyId: 's_canon',
          chapterId: 'ch_canon_1',
          nodeId: 'n1',
          expectedMoves: [RepertoireMove(from: 'e2', to: 'e4', san: 'e4')],
          canonicalStateId: 'sha1_canon_hash_123',
        );
        await repo.saveDecision(dec);

        final loaded = await repo.getDecision('dec_canon_1');
        expect(loaded, isNotNull);
        expect(loaded!.canonicalStateId, 'sha1_canon_hash_123');
        expect(loaded.canonicalId, 'sha1_canon_hash_123');
      } finally {
        await db.close();
      }
    });

    test('chapter orientation round-trips for both White and Black', () async {
      var db = await openAppDatabase(databaseFactoryFfi, dbPath);
      var repo = SqliteStudyRepository(db);

      try {
        const study = Study(id: 'study-orient', title: 'Orientation Test');
        final chWhite = Chapter(
          id: 'ch-w',
          studyId: study.id,
          sourceOrder: 0,
          title: 'White Line',
          orientation: Side.white,
        );
        final chBlack = Chapter(
          id: 'ch-b',
          studyId: study.id,
          sourceOrder: 1,
          title: 'Black Line',
          orientation: Side.black,
        );

        await repo.saveStudy(study);
        await repo.saveChapters([chWhite, chBlack]);

        await db.close();
        db = await openAppDatabase(databaseFactoryFfi, dbPath);
        repo = SqliteStudyRepository(db);

        final loadedW = await repo.getChapter('ch-w');
        final loadedB = await repo.getChapter('ch-b');

        expect(loadedW?.orientation, Side.white);
        expect(loadedB?.orientation, Side.black);
      } finally {
        await db.close();
      }
    });
  });
}
