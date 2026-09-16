// Copyright (C) 2024 ChessSRS contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:sqflite/sqflite.dart';

const kTableSrsStudy = 'srs_study';
const kTableSrsChapter = 'srs_chapter';
const kTableSrsDecision = 'srs_decision';
const kTableSrsReviewState = 'srs_review_state';
const kTableSrsReviewEvent = 'srs_review_event';

void createSrsTables(Batch batch) {
  batch.execute('''
    CREATE TABLE IF NOT EXISTS $kTableSrsStudy (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      createdAt TEXT NOT NULL,
      updatedAt TEXT NOT NULL,
      isActive INTEGER NOT NULL DEFAULT 1
    );
  ''');

  batch.execute('''
    CREATE TABLE IF NOT EXISTS $kTableSrsChapter (
      id TEXT PRIMARY KEY,
      studyId TEXT NOT NULL,
      sourceOrder INTEGER NOT NULL,
      title TEXT,
      startingFen TEXT,
      createdAt TEXT NOT NULL,
      treeJson TEXT,
      opening TEXT,
      FOREIGN KEY (studyId) REFERENCES $kTableSrsStudy(id) ON DELETE CASCADE
    );
  ''');
  batch.execute('''
    CREATE INDEX IF NOT EXISTS idx_srs_chapter_studyId
    ON $kTableSrsChapter(studyId);
  ''');

  batch.execute('''
    CREATE TABLE IF NOT EXISTS $kTableSrsDecision (
      id TEXT PRIMARY KEY,
      studyId TEXT NOT NULL,
      chapterId TEXT NOT NULL,
      nodeId TEXT NOT NULL,
      expectedMoves TEXT NOT NULL,
      FOREIGN KEY (studyId) REFERENCES $kTableSrsStudy(id) ON DELETE CASCADE,
      FOREIGN KEY (chapterId) REFERENCES $kTableSrsChapter(id) ON DELETE CASCADE
    );
  ''');
  batch.execute('''
    CREATE INDEX IF NOT EXISTS idx_srs_decision_studyId
    ON $kTableSrsDecision(studyId);
  ''');
  batch.execute('''
    CREATE INDEX IF NOT EXISTS idx_srs_decision_chapterId
    ON $kTableSrsDecision(chapterId);
  ''');

  batch.execute('''
    CREATE TABLE IF NOT EXISTS $kTableSrsReviewState (
      decisionId TEXT PRIMARY KEY,
      firstReviewedAt TEXT,
      lastReviewedAt TEXT,
      nextDueAt TEXT,
      repetitionCount INTEGER NOT NULL DEFAULT 0,
      lapseCount INTEGER NOT NULL DEFAULT 0,
      stability REAL NOT NULL DEFAULT 0.0,
      FOREIGN KEY (decisionId) REFERENCES $kTableSrsDecision(id) ON DELETE CASCADE
    );
  ''');
  batch.execute('''
    CREATE INDEX IF NOT EXISTS idx_srs_review_state_nextDueAt
    ON $kTableSrsReviewState(nextDueAt);
  ''');

  batch.execute('''
    CREATE TABLE IF NOT EXISTS $kTableSrsReviewEvent (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      decisionId TEXT NOT NULL,
      whenTimestamp TEXT NOT NULL,
      result TEXT NOT NULL,
      oldStateJson TEXT NOT NULL,
      newStateJson TEXT NOT NULL,
      FOREIGN KEY (decisionId) REFERENCES $kTableSrsDecision(id) ON DELETE CASCADE
    );
  ''');
  batch.execute('''
    CREATE INDEX IF NOT EXISTS idx_srs_review_event_decisionId
    ON $kTableSrsReviewEvent(decisionId);
  ''');
}
