// Copyright (C) 2024 ChessSRS contributors
// SPDX-License-Identifier: GPL-3.0-or-later

/// Scope filter for a review session.
class ReviewScope {
  const ReviewScope.all() : studyId = null, chapterId = null;

  const ReviewScope.study(String this.studyId) : chapterId = null;

  const ReviewScope.chapter({required String this.studyId, required String this.chapterId});

  final String? studyId;
  final String? chapterId;

  bool matches({required String studyId, required String chapterId}) {
    if (this.studyId != null && this.studyId != studyId) {
      return false;
    }
    if (this.chapterId != null && this.chapterId != chapterId) {
      return false;
    }
    return true;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReviewScope && other.studyId == studyId && other.chapterId == chapterId;

  @override
  int get hashCode => Object.hash(studyId, chapterId);

  @override
  String toString() => 'ReviewScope(study: $studyId, chapter: $chapterId)';
}
