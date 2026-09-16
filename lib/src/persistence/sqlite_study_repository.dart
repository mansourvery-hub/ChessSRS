// Copyright (C) 2024 ChessSRS contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:convert';

import 'package:chess_srs/src/domain/domain.dart';
import 'package:chess_srs/src/import/pgn_importer.dart';
import 'package:chess_srs/src/persistence/json_adapters.dart';
import 'package:chess_srs/src/persistence/srs_schema.dart';
import 'package:chess_srs/src/persistence/study_repository.dart';
import 'package:sqflite/sqflite.dart';

/// Concrete SQLite implementation of [StudyRepository].
///
/// Ensures incremental persistence: review answers touch only the affected
/// decision's [ReviewState] and append one [ReviewEvent] without touching
/// study or chapter trees (QUALITY.md §1.5).
class SqliteStudyRepository implements StudyRepository {
  const SqliteStudyRepository(this._db);

  final Database _db;

  @override
  Future<void> saveImportResult(ImportResult result) async {
    await _db.transaction((txn) async {
      final now = DateTime.now().toIso8601String();
      await txn.insert(kTableSrsStudy, {
        'id': result.study.id,
        'title': result.study.title,
        'createdAt': result.study.createdAt?.toIso8601String() ?? now,
        'updatedAt': result.study.updatedAt?.toIso8601String() ?? now,
        'isActive': result.study.isActive ? 1 : 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      final chapterBatch = txn.batch();
      for (final chapter in result.chapters) {
        final treeJson = chapter.root != null
            ? jsonEncode(repertoireNodeToJson(chapter.root!))
            : null;
        chapterBatch.insert(kTableSrsChapter, {
          'id': chapter.id,
          'studyId': chapter.studyId,
          'sourceOrder': chapter.sourceOrder,
          'title': chapter.title,
          'startingFen': chapter.startingFen,
          'createdAt': (chapter.createdAt ?? DateTime.now()).toIso8601String(),
          'treeJson': treeJson,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await chapterBatch.commit(noResult: true);

      final decisionBatch = txn.batch();
      for (final d in result.decisions) {
        decisionBatch.insert(kTableSrsDecision, {
          'id': d.id,
          'studyId': d.studyId,
          'chapterId': d.chapterId,
          'nodeId': d.nodeId,
          'expectedMoves': encodeExpectedMoves(d.expectedMoves),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await decisionBatch.commit(noResult: true);
    });
  }

  // ---------------------------------------------------------------------------
  // Studies
  // ---------------------------------------------------------------------------

  @override
  Future<void> saveStudy(Study study) async {
    final now = DateTime.now().toIso8601String();
    await _db.insert(kTableSrsStudy, {
      'id': study.id,
      'title': study.title,
      'createdAt': study.createdAt?.toIso8601String() ?? now,
      'updatedAt': study.updatedAt?.toIso8601String() ?? now,
      'isActive': study.isActive ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<Study?> getStudy(String id) async {
    final rows = await _db.query(kTableSrsStudy, where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return _studyFromRow(rows.first);
  }

  @override
  Future<List<Study>> getAllStudies() async {
    final rows = await _db.query(kTableSrsStudy, orderBy: 'createdAt ASC');
    return rows.map(_studyFromRow).toList(growable: false);
  }

  @override
  Future<List<Study>> getActiveStudies() async {
    final rows = await _db.query(kTableSrsStudy, where: 'isActive = 1', orderBy: 'createdAt ASC');
    return rows.map(_studyFromRow).toList(growable: false);
  }

  @override
  Future<void> updateStudyActive(String studyId, bool isActive) async {
    final now = DateTime.now().toIso8601String();
    await _db.update(
      kTableSrsStudy,
      {'isActive': isActive ? 1 : 0, 'updatedAt': now},
      where: 'id = ?',
      whereArgs: [studyId],
    );
  }

  @override
  Future<void> deleteStudy(String id) async {
    await _db.transaction((txn) async {
      // Find all decisions belonging to this study
      final decisions = await txn.query(
        kTableSrsDecision,
        columns: ['id'],
        where: 'studyId = ?',
        whereArgs: [id],
      );
      final decisionIds = decisions.map((d) => d['id']! as String).toList();

      if (decisionIds.isNotEmpty) {
        final placeholders = List.filled(decisionIds.length, '?').join(',');
        await txn.delete(
          kTableSrsReviewEvent,
          where: 'decisionId IN ($placeholders)',
          whereArgs: decisionIds,
        );
        await txn.delete(
          kTableSrsReviewState,
          where: 'decisionId IN ($placeholders)',
          whereArgs: decisionIds,
        );
        await txn.delete(kTableSrsDecision, where: 'studyId = ?', whereArgs: [id]);
      }

      await txn.delete(kTableSrsChapter, where: 'studyId = ?', whereArgs: [id]);
      await txn.delete(kTableSrsStudy, where: 'id = ?', whereArgs: [id]);
    });
  }

  // ---------------------------------------------------------------------------
  // Chapters
  // ---------------------------------------------------------------------------

  @override
  Future<void> saveChapter(Chapter chapter) async {
    final treeJson = chapter.root != null ? jsonEncode(repertoireNodeToJson(chapter.root!)) : null;

    await _db.insert(kTableSrsChapter, {
      'id': chapter.id,
      'studyId': chapter.studyId,
      'sourceOrder': chapter.sourceOrder,
      'title': chapter.title,
      'startingFen': chapter.startingFen,
      'createdAt': (chapter.createdAt ?? DateTime.now()).toIso8601String(),
      'treeJson': treeJson,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> saveChapters(List<Chapter> chapters) async {
    final batch = _db.batch();
    for (final chapter in chapters) {
      final treeJson = chapter.root != null
          ? jsonEncode(repertoireNodeToJson(chapter.root!))
          : null;

      batch.insert(kTableSrsChapter, {
        'id': chapter.id,
        'studyId': chapter.studyId,
        'sourceOrder': chapter.sourceOrder,
        'title': chapter.title,
        'startingFen': chapter.startingFen,
        'createdAt': (chapter.createdAt ?? DateTime.now()).toIso8601String(),
        'treeJson': treeJson,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<Chapter?> getChapter(String id) async {
    final rows = await _db.query(kTableSrsChapter, where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return _chapterFromRow(rows.first);
  }

  @override
  Future<List<Chapter>> getChaptersByStudy(String studyId) async {
    final rows = await _db.query(
      kTableSrsChapter,
      where: 'studyId = ?',
      whereArgs: [studyId],
      orderBy: 'sourceOrder ASC',
    );
    return rows.map(_chapterFromRow).toList(growable: false);
  }

  @override
  Future<void> deleteChapter(String id) async {
    await _db.transaction((txn) async {
      final decisions = await txn.query(
        kTableSrsDecision,
        columns: ['id'],
        where: 'chapterId = ?',
        whereArgs: [id],
      );
      final decisionIds = decisions.map((d) => d['id']! as String).toList();

      if (decisionIds.isNotEmpty) {
        final placeholders = List.filled(decisionIds.length, '?').join(',');
        await txn.delete(
          kTableSrsReviewEvent,
          where: 'decisionId IN ($placeholders)',
          whereArgs: decisionIds,
        );
        await txn.delete(
          kTableSrsReviewState,
          where: 'decisionId IN ($placeholders)',
          whereArgs: decisionIds,
        );
        await txn.delete(kTableSrsDecision, where: 'chapterId = ?', whereArgs: [id]);
      }

      await txn.delete(kTableSrsChapter, where: 'id = ?', whereArgs: [id]);
    });
  }

  // ---------------------------------------------------------------------------
  // Position Trees
  // ---------------------------------------------------------------------------

  @override
  Future<RepertoireNode?> getPositionTree(String chapterId) async {
    final rows = await _db.query(
      kTableSrsChapter,
      columns: ['treeJson'],
      where: 'id = ?',
      whereArgs: [chapterId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final treeJson = rows.first['treeJson'] as String?;
    if (treeJson == null || treeJson.isEmpty) return null;
    return repertoireNodeFromJson(jsonDecode(treeJson) as Map<String, dynamic>);
  }

  @override
  Future<void> savePositionTree(String chapterId, RepertoireNode root) async {
    final treeJson = jsonEncode(repertoireNodeToJson(root));
    await _db.update(
      kTableSrsChapter,
      {'treeJson': treeJson},
      where: 'id = ?',
      whereArgs: [chapterId],
    );
  }

  // ---------------------------------------------------------------------------
  // Decisions
  // ---------------------------------------------------------------------------

  @override
  Future<void> saveDecision(RepertoireDecision decision) async {
    await _db.insert(kTableSrsDecision, {
      'id': decision.id,
      'studyId': decision.studyId,
      'chapterId': decision.chapterId,
      'nodeId': decision.nodeId,
      'expectedMoves': encodeExpectedMoves(decision.expectedMoves),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> saveDecisions(List<RepertoireDecision> decisions) async {
    final batch = _db.batch();
    for (final d in decisions) {
      batch.insert(kTableSrsDecision, {
        'id': d.id,
        'studyId': d.studyId,
        'chapterId': d.chapterId,
        'nodeId': d.nodeId,
        'expectedMoves': encodeExpectedMoves(d.expectedMoves),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<RepertoireDecision?> getDecision(String id) async {
    final rows = await _db.query(kTableSrsDecision, where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return _decisionFromRow(rows.first);
  }

  @override
  Future<List<RepertoireDecision>> getDecisionsByChapter(String chapterId) async {
    final rows = await _db.query(kTableSrsDecision, where: 'chapterId = ?', whereArgs: [chapterId]);
    return rows.map(_decisionFromRow).toList(growable: false);
  }

  @override
  Future<List<RepertoireDecision>> getDecisionsByStudy(String studyId) async {
    final rows = await _db.query(kTableSrsDecision, where: 'studyId = ?', whereArgs: [studyId]);
    return rows.map(_decisionFromRow).toList(growable: false);
  }

  @override
  Future<List<RepertoireDecision>> getAllDecisions() async {
    final rows = await _db.query(kTableSrsDecision);
    return rows.map(_decisionFromRow).toList(growable: false);
  }

  @override
  Future<void> deleteDecisionsByStudy(String studyId) async {
    await _db.delete(kTableSrsDecision, where: 'studyId = ?', whereArgs: [studyId]);
  }

  // ---------------------------------------------------------------------------
  // Review States (SRS)
  // ---------------------------------------------------------------------------

  @override
  Future<void> saveReviewState(ReviewState state) async {
    await _db.insert(kTableSrsReviewState, {
      'decisionId': state.decisionId,
      'firstReviewedAt': state.firstReviewedAt?.toIso8601String(),
      'lastReviewedAt': state.lastReviewedAt?.toIso8601String(),
      'nextDueAt': state.nextDueAt?.toIso8601String(),
      'repetitionCount': state.repetitionCount,
      'lapseCount': state.lapseCount,
      'stability': state.stability,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> saveReviewStates(List<ReviewState> states) async {
    final batch = _db.batch();
    for (final s in states) {
      batch.insert(kTableSrsReviewState, {
        'decisionId': s.decisionId,
        'firstReviewedAt': s.firstReviewedAt?.toIso8601String(),
        'lastReviewedAt': s.lastReviewedAt?.toIso8601String(),
        'nextDueAt': s.nextDueAt?.toIso8601String(),
        'repetitionCount': s.repetitionCount,
        'lapseCount': s.lapseCount,
        'stability': s.stability,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<ReviewState?> getReviewState(String decisionId) async {
    final rows = await _db.query(
      kTableSrsReviewState,
      where: 'decisionId = ?',
      whereArgs: [decisionId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _reviewStateFromRow(rows.first);
  }

  @override
  Future<List<ReviewState>> getAllReviewStates() async {
    final rows = await _db.query(kTableSrsReviewState);
    return rows.map(_reviewStateFromRow).toList(growable: false);
  }

  @override
  Future<List<ReviewState>> getDueReviewStates(DateTime now) async {
    final rows = await _db.query(
      kTableSrsReviewState,
      where: 'nextDueAt IS NULL OR nextDueAt <= ?',
      whereArgs: [now.toIso8601String()],
      orderBy: 'nextDueAt ASC',
    );
    return rows.map(_reviewStateFromRow).toList(growable: false);
  }

  // ---------------------------------------------------------------------------
  // Review Events (SRS history)
  // ---------------------------------------------------------------------------

  @override
  Future<void> saveReviewEvent(ReviewEvent event) async {
    await _db.insert(kTableSrsReviewEvent, {
      'decisionId': event.decisionId,
      'whenTimestamp': event.when.toIso8601String(),
      'result': event.result.name,
      'oldStateJson': jsonEncode(reviewStateToJson(event.oldState)),
      'newStateJson': jsonEncode(reviewStateToJson(event.newState)),
    });
  }

  @override
  Future<List<ReviewEvent>> getReviewEvents(String decisionId) async {
    final rows = await _db.query(
      kTableSrsReviewEvent,
      where: 'decisionId = ?',
      whereArgs: [decisionId],
      orderBy: 'whenTimestamp ASC',
    );
    return rows.map(_reviewEventFromRow).toList(growable: false);
  }

  // ---------------------------------------------------------------------------
  // Row mappers
  // ---------------------------------------------------------------------------

  static Study _studyFromRow(Map<String, Object?> row) {
    final rawActive = row['isActive'];
    final isActive = rawActive == null || rawActive != 0;
    return Study(
      id: row['id']! as String,
      title: row['title']! as String,
      createdAt: DateTime.parse(row['createdAt']! as String),
      updatedAt: DateTime.parse(row['updatedAt']! as String),
      isActive: isActive,
    );
  }

  static Chapter _chapterFromRow(Map<String, Object?> row) {
    final treeJson = row['treeJson'] as String?;
    final root = treeJson != null && treeJson.isNotEmpty
        ? repertoireNodeFromJson(jsonDecode(treeJson) as Map<String, dynamic>)
        : null;

    return Chapter(
      id: row['id']! as String,
      studyId: row['studyId']! as String,
      sourceOrder: (row['sourceOrder']! as num).toInt(),
      title: row['title'] as String?,
      startingFen: row['startingFen'] as String?,
      root: root,
      createdAt: DateTime.parse(row['createdAt']! as String),
    );
  }

  static RepertoireDecision _decisionFromRow(Map<String, Object?> row) {
    final rawMoves = row['expectedMoves']! as String;
    return RepertoireDecision(
      id: row['id']! as String,
      studyId: row['studyId']! as String,
      chapterId: row['chapterId']! as String,
      nodeId: row['nodeId']! as String,
      expectedMoves: decodeExpectedMoves(rawMoves),
    );
  }

  static ReviewState _reviewStateFromRow(Map<String, Object?> row) {
    final first = row['firstReviewedAt'] as String?;
    final last = row['lastReviewedAt'] as String?;
    final next = row['nextDueAt'] as String?;

    return ReviewState(
      decisionId: row['decisionId']! as String,
      firstReviewedAt: first != null ? DateTime.parse(first) : null,
      lastReviewedAt: last != null ? DateTime.parse(last) : null,
      nextDueAt: next != null ? DateTime.parse(next) : null,
      repetitionCount: (row['repetitionCount']! as num).toInt(),
      lapseCount: (row['lapseCount']! as num).toInt(),
      stability: (row['stability']! as num).toDouble(),
    );
  }

  static ReviewEvent _reviewEventFromRow(Map<String, Object?> row) {
    return ReviewEvent(
      decisionId: row['decisionId']! as String,
      when: DateTime.parse(row['whenTimestamp']! as String),
      result: ReviewResult.values.byName(row['result']! as String),
      oldState: reviewStateFromJson(
        jsonDecode(row['oldStateJson']! as String) as Map<String, dynamic>,
      ),
      newState: reviewStateFromJson(
        jsonDecode(row['newStateJson']! as String) as Map<String, dynamic>,
      ),
    );
  }
}
