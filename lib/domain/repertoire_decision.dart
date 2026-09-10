import 'package:equatable/equatable.dart';

import 'package:chess_repertoire_srs/core/ids.dart';
import 'package:chess_repertoire_srs/domain/entities/repertoire_move.dart';

/// A decision the user may be asked to recall: from a given position, play one
/// of the accepted repertoire moves.
class RepertoireDecision extends Equatable {
  const RepertoireDecision({
    required this.id,
    required this.studyId,
    required this.chapterId,
    required this.nodeId,
    required this.expectedMoves,
  });

  factory RepertoireDecision.create({
    required String studyId,
    required String chapterId,
    required String nodeId,
    required List<RepertoireMove> expectedMoves,
  }) {
    return RepertoireDecision(
      id: uuid.v4(),
      studyId: studyId,
      chapterId: chapterId,
      nodeId: nodeId,
      expectedMoves: List.unmodifiable(expectedMoves),
    );
  }

  final String id;

  final String studyId;

  final String chapterId;

  final String nodeId;

  /// Zero or more accepted repertoire continuations. When empty, reviewers
  /// should still have legal-opener fallback (nothing expected).
  final List<RepertoireMove> expectedMoves;

  bool accepts(RepertoireMove move) {
    return expectedMoves.any(
      (m) => m.from == move.from && m.to == move.to && m.promotion == move.promotion,
    );
  }

  @override
  bool get stringify => true;

  @override
  List<Object?> get props => [id, studyId, chapterId, nodeId, expectedMoves];
}