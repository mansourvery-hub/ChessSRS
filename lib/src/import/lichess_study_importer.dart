// Copyright (C) 2024 ChessSRS contributors
// SPDX-License-Identifier: GPL-3.0-or-later

typedef LichessStudyReference = ({String id, String host});

/// Parses a Lichess study URL or raw 8-character ID into an id and host.
///
/// Supports full URLs (e.g. `https://lichess.org/study/xxxxxx` or `lichess.org/study/xxxxxx/chapter`),
/// subdomains (`lichess.dev`), and raw 8-character study IDs (defaults to `lichess.org`).
LichessStudyReference? parseLichessStudyReference(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return null;

  // Direct 8-character alphanumeric ID (defaults to lichess.org)
  if (RegExp(r'^[a-zA-Z0-9]{8}$').hasMatch(trimmed)) {
    return (id: trimmed, host: 'lichess.org');
  }

  // URL matching lichess.(org|dev)/study/{id}
  final urlMatch = RegExp(
    r'(?:https?:\/\/)?(?:www\.)?lichess\.(org|dev)\/study\/([a-zA-Z0-9]{8})',
  ).firstMatch(trimmed);

  if (urlMatch != null) {
    final domain = urlMatch.group(1) ?? 'org';
    final id = urlMatch.group(2)!;
    return (id: id, host: 'lichess.$domain');
  }

  return null;
}

/// Extracts the 8-character Lichess study ID from a URL or raw ID string.
String? extractLichessStudyId(String input) {
  return parseLichessStudyReference(input)?.id;
}

/// Attempts to extract a study-level title from Lichess PGN headers.
///
/// Checks `[StudyName "..."]` header first, then falls back to `[Event "Study Name: Chapter Name"]`.
String? extractStudyTitleFromPgn(String pgnText) {
  final studyNameMatch = RegExp(r'\[StudyName\s+"([^"]+)"\]').firstMatch(pgnText);
  if (studyNameMatch != null) {
    final studyName = studyNameMatch.group(1)?.trim();
    if (studyName != null && studyName.isNotEmpty) {
      return studyName;
    }
  }

  final eventMatch = RegExp(r'\[Event\s+"([^"]+)"\]').firstMatch(pgnText);
  if (eventMatch != null) {
    final eventValue = eventMatch.group(1)?.trim();
    if (eventValue != null && eventValue.contains(':')) {
      final studyPart = eventValue.split(':').first.trim();
      if (studyPart.isNotEmpty) {
        return studyPart;
      }
    }
  }
  return null;
}
