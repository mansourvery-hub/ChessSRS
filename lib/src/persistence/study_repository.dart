// Copyright (C) 2024 ChessSRS contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:chess_srs/src/db/database.dart';
import 'package:chess_srs/src/domain/domain.dart';
import 'package:chess_srs/src/import/pgn_importer.dart';
import 'package:chess_srs/src/persistence/sqlite_study_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for the application's [StudyRepository].
final srsStudyRepositoryProvider = FutureProvider<StudyRepository>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return SqliteStudyRepository(db);
}, name: 'SrsStudyRepositoryProvider');

/// Abstract interface for local persistence of studies, chapters, trees,
/// decisions, and spaced repetition review states.
abstract class StudyRepository {
  // Bulk import
  Future<void> saveImportResult(ImportResult result);

  // Studies
  Future<void> saveStudy(Study study);
  Future<Study?> getStudy(String id);
  Future<List<Study>> getAllStudies();
  Future<void> deleteStudy(String id);

  // Chapters
  Future<void> saveChapter(Chapter chapter);
  Future<void> saveChapters(List<Chapter> chapters);
  Future<Chapter?> getChapter(String id);
  Future<List<Chapter>> getChaptersByStudy(String studyId);
  Future<void> deleteChapter(String id);

  // Position Trees
  Future<RepertoireNode?> getPositionTree(String chapterId);
  Future<void> savePositionTree(String chapterId, RepertoireNode root);

  // Decisions
  Future<void> saveDecision(RepertoireDecision decision);
  Future<void> saveDecisions(List<RepertoireDecision> decisions);
  Future<RepertoireDecision?> getDecision(String id);
  Future<List<RepertoireDecision>> getDecisionsByChapter(String chapterId);
  Future<List<RepertoireDecision>> getDecisionsByStudy(String studyId);
  Future<List<RepertoireDecision>> getAllDecisions();
  Future<void> deleteDecisionsByStudy(String studyId);

  // Review states (SRS)
  Future<void> saveReviewState(ReviewState state);
  Future<void> saveReviewStates(List<ReviewState> states);
  Future<ReviewState?> getReviewState(String decisionId);
  Future<List<ReviewState>> getAllReviewStates();
  Future<List<ReviewState>> getDueReviewStates(DateTime now);

  // Review events (SRS log)
  Future<void> saveReviewEvent(ReviewEvent event);
  Future<List<ReviewEvent>> getReviewEvents(String decisionId);
}
