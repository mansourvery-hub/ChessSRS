// Copyright (C) 2024 ChessSRS contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:chess_srs/src/domain/ids.dart';
import 'package:chess_srs/src/domain/repertoire_node.dart';

/// A single chapter within a [Study], corresponding to one PGN game.
///
/// A chapter owns its [root] position tree. When the source PGN uses a
/// non-standard starting position (FEN header), [startingFen] captures it.
/// Source order ([sourceOrder]) preserves the chapter sequence from the file.
class Chapter {
  const Chapter({
    required this.id,
    required this.studyId,
    required this.sourceOrder,
    this.title,
    this.startingFen,
    this.root,
    this.createdAt,
  });

  /// Creates a new [Chapter] with a freshly-generated UUID.
  factory Chapter.create({
    required String studyId,
    required int sourceOrder,
    String? title,
    String? startingFen,
    RepertoireNode? root,
    DateTime? createdAt,
  }) {
    return Chapter(
      id: newId(),
      studyId: studyId,
      sourceOrder: sourceOrder,
      title: title,
      startingFen: startingFen,
      root: root,
      createdAt: createdAt ?? DateTime.now(),
    );
  }

  final String id;
  final String studyId;

  /// Position of this chapter among siblings (0-based).
  final int sourceOrder;

  /// Optional human-readable chapter name from the PGN.
  final String? title;

  /// Non-standard starting FEN (null ⇒ standard initial position).
  final String? startingFen;

  /// Root of the repertoire position tree for this chapter.
  final RepertoireNode? root;

  final DateTime? createdAt;

  Chapter copyWith({
    String? title,
    String? startingFen,
    RepertoireNode? root,
  }) {
    return Chapter(
      id: id,
      studyId: studyId,
      sourceOrder: sourceOrder,
      title: title ?? this.title,
      startingFen: startingFen ?? this.startingFen,
      root: root ?? this.root,
      createdAt: createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Chapter &&
          other.id == id &&
          other.studyId == studyId &&
          other.sourceOrder == sourceOrder &&
          other.title == title &&
          other.startingFen == startingFen &&
          other.root == root;

  @override
  int get hashCode => Object.hash(id, studyId, sourceOrder, title, startingFen, root);

  @override
  String toString() => 'Chapter(id: $id, studyId: $studyId, title: $title)';
}
