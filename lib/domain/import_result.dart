import 'package:equatable/equatable.dart';

import 'package:chess_repertoire_srs/domain/entities/study.dart';
import 'package:chess_repertoire_srs/domain/entities/chapter.dart';

/// The type of scope for review.
enum ReviewScope {
  all,
  study,
  chapter,
}

class ReviewScopeValue extends Equatable {
  const ReviewScopeValue(this.type, this.id);

  final ReviewScope type;
  final String? id;

  bool get isAll => type == ReviewScope.all;
  bool get isStudy => type == ReviewScope.study;
  bool get isChapter => type == ReviewScope.chapter;

  @override
  bool get stringify => true;

  @override
  List<Object?> get props => [type, id];
}

/// Results of importing a PGN file.
class ImportResult extends Equatable {
  const ImportResult({
    required this.study,
    required this.chapters,
    required this.errors,
    required this.warnings,
  });

  final Study study;
  final List<Chapter> chapters;
  final List<ImportError> errors;
  final List<String> warnings;

  ImportResult copyWith({
    Study? study,
    List<Chapter>? chapters,
    List<ImportError>? errors,
    List<String>? warnings,
  }) {
    return ImportResult(
      study: study ?? this.study,
      chapters: chapters ?? this.chapters,
      errors: errors ?? this.errors,
      warnings: warnings ?? this.warnings,
    );
  }

  bool get hasErrors => errors.isNotEmpty;
  bool get hasWarnings => warnings.isNotEmpty;

  @override
  bool get stringify => true;

  @override
  List<Object?> get props => [study, chapters, errors, warnings];
}

class ImportError extends Equatable {
  const ImportError({
    required this.chapterTitle,
    required this.moveNumber,
    required this.message,
  });

  final String chapterTitle;
  final int moveNumber;
  final String message;

  @override
  bool get stringify => true;

  @override
  List<Object?> get props => [chapterTitle, moveNumber, message];
}