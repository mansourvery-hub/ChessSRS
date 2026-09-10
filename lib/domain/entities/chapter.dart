import 'package:equatable/equatable.dart';

import 'package:chess_repertoire_srs/core/ids.dart';
import 'package:chess_repertoire_srs/domain/entities/position_node.dart';

/// A logical unit from the source PGN — commonly a game or a named study chapter.
class Chapter extends Equatable {
  const Chapter({
    required this.id,
    required this.studyId,
    required this.sourceOrder,
    this.title,
    this.startingFen,
    this.root,
    this.createdAt,
  });

  factory Chapter.create({
    required String studyId,
    required int sourceOrder,
    String? title,
    String? startingFen,
    PositionNode? root,
    DateTime? createdAt,
  }) {
    final now = createdAt ?? DateTime.now();
    return Chapter(
      id: uuid.v4(),
      studyId: studyId,
      sourceOrder: sourceOrder,
      title: title,
      startingFen: startingFen,
      root: root,
      createdAt: now,
    );
  }

  Chapter copyWith({
    String? title,
    String? startingFen,
    PositionNode? root,
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

  static const empty = Chapter(id: '', studyId: '', sourceOrder: 0);

  final String id;

  final String studyId;

  /// Preserve the source ordering of chapters/games inside one study.
  final int sourceOrder;

  final String? title;

  /// The chapter root position. When null it means the default starting position.
  final String? startingFen;

  final PositionNode? root;

  final DateTime? createdAt;

  @override
  bool get stringify => true;

  @override
  List<Object?> get props => [id, studyId, sourceOrder, title, startingFen, root];
}