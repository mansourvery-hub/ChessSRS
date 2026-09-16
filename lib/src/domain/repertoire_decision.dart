// Copyright (C) 2024 ChessSRS contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:chess_srs/src/domain/ids.dart';
import 'package:chess_srs/src/domain/repertoire_move.dart';

/// The scheduled unit of active recall.
///
/// A [RepertoireDecision] represents a *position from the player's perspective*
/// in which the player must recall one of the expected repertoire continuations.
///
/// Only moves the **player must recall** become decisions. Opponent moves are
/// not independently scheduled — they are auto-played during traversal.
///
/// Inspired by chessrs `Move` entity (GPL-3.0, ZackMurry/chessrs); reimplemented
/// cleanly in Dart against our own contracts.
class RepertoireDecision {
  const RepertoireDecision({
    required this.id,
    required this.studyId,
    required this.chapterId,
    required this.nodeId,
    required this.expectedMoves,
  });

  /// Creates a new [RepertoireDecision] with a freshly-generated UUID.
  factory RepertoireDecision.create({
    required String studyId,
    required String chapterId,
    required String nodeId,
    required List<RepertoireMove> expectedMoves,
  }) {
    return RepertoireDecision(
      id: newId(),
      studyId: studyId,
      chapterId: chapterId,
      nodeId: nodeId,
      expectedMoves: List.unmodifiable(expectedMoves),
    );
  }

  final String id;
  final String studyId;
  final String chapterId;

  /// The [RepertoireNode.id] of the position from which the player must move.
  final String nodeId;

  /// Accepted repertoire continuations. Any matching move is considered correct.
  final List<RepertoireMove> expectedMoves;

  /// Returns true if [move] is one of the accepted continuations.
  bool accepts(RepertoireMove move) => expectedMoves.any((m) => m.matches(move));

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RepertoireDecision &&
          other.id == id &&
          other.studyId == studyId &&
          other.chapterId == chapterId &&
          other.nodeId == nodeId;

  @override
  int get hashCode => Object.hash(id, studyId, chapterId, nodeId);

  @override
  String toString() => 'RepertoireDecision(id: $id, nodeId: $nodeId)';
}
