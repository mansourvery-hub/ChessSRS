import 'package:equatable/equatable.dart';

import 'package:chess_repertoire_srs/core/ids.dart';

/// A user-owned collection of chapters imported from a single source.
class Study extends Equatable {
  const Study({
    required this.id,
    required this.title,
    this.createdAt,
    this.updatedAt,
  });

  factory Study.create({
    required String title,
    DateTime? createdAt,
  }) {
    final now = createdAt ?? DateTime.now();
    return Study(id: uuid.v4(), title: title, createdAt: now, updatedAt: now);
  }

  static const empty = Study(id: '', title: '');

  final String id;

  final String title;

  final DateTime? createdAt;

  final DateTime? updatedAt;

  Study copyWith({
    String? title,
    DateTime? updatedAt,
  }) {
    return Study(
      id: id,
      title: title ?? this.title,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool get stringify => true;

  @override
  List<Object?> get props => [id, title, createdAt, updatedAt];
}