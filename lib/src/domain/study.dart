// Copyright (C) 2024 ChessSRS contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:chess_srs/src/domain/ids.dart';

/// A user-owned collection of chapters imported from a single PGN source file.
///
/// The [Study] is the top-level container: it holds metadata and zero or more
/// [Chapter]s (one per PGN game) that together form the repertoire material.
class Study {
  const Study({
    required this.id,
    required this.title,
    this.createdAt,
    this.updatedAt,
    this.isActive = true,
  });

  /// Creates a new [Study] with a freshly-generated UUID.
  factory Study.create({required String title, DateTime? createdAt, bool isActive = true}) {
    final now = createdAt ?? DateTime.now();
    return Study(id: newId(), title: title, createdAt: now, updatedAt: now, isActive: isActive);
  }

  /// The unique stable identifier for this study.
  final String id;

  /// Human-readable study title (typically the PGN filename or a user label).
  final String title;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Whether this study is included in the global daily review pool (PRODUCT.md Journey 5).
  final bool isActive;

  Study copyWith({String? title, DateTime? updatedAt, bool? isActive}) {
    return Study(
      id: id,
      title: title ?? this.title,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Study &&
          other.id == id &&
          other.title == title &&
          other.createdAt == createdAt &&
          other.updatedAt == updatedAt &&
          other.isActive == isActive;

  @override
  int get hashCode => Object.hash(id, title, createdAt, updatedAt, isActive);

  @override
  String toString() => 'Study(id: $id, title: $title, active: $isActive)';
}
