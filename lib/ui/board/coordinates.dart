/// Coordinate utilities for chess board
/// Ported from chessrs squareIndexToCoordinates.ts

/// Converts 0-based file (0-7) and rank (0-7) indices to algebraic notation (e.g., "e4")
/// File 0 = 'a', Rank 0 = '1' (from white's perspective)
String squareIndexToCoordinates(int file, int rank) {
  if (file < 0 || file > 7 || rank < 0 || rank > 7) {
    throw ArgumentError('Invalid square index: ($file, $rank) - must be 0-7');
  }
  final fileChar = String.fromCharCode('a'.codeUnitAt(0) + file);
  final rankChar = (rank + 1).toString();
  return '$fileChar$rankChar';
}

/// Converts algebraic notation (e.g., "e4") to 0-based file and rank indices
/// Returns null if invalid
({int file, int rank})? coordinatesToIndex(String square) {
  if (square.length != 2) return null;
  final fileChar = square[0].toLowerCase();
  final rankChar = square[1];
  if (fileChar.codeUnitAt(0) < 'a'.codeUnitAt(0) || fileChar.codeUnitAt(0) > 'h'.codeUnitAt(0)) {
    return null;
  }
  final file = fileChar.codeUnitAt(0) - 'a'.codeUnitAt(0);
  final rank = int.tryParse(rankChar);
  if (rank == null || rank < 1 || rank > 8) return null;
  return (file: file, rank: rank - 1);
}

/// Converts a square index (0-63) to algebraic notation
/// Standard chess array indexing: 0 = a8, 7 = h8, 56 = a1, 63 = h1
String squareIndexToAlgebraic(int index) {
  if (index < 0 || index > 63) {
    throw ArgumentError('Invalid square index: $index');
  }
  final file = index % 8;
  final rank = 7 - (index ~/ 8);
  return squareIndexToCoordinates(file, rank);
}

/// Converts algebraic notation to 0-63 square index
int algebraicToSquareIndex(String square) {
  final coords = coordinatesToIndex(square);
  if (coords == null) {
    throw ArgumentError('Invalid square: $square');
  }
  return (7 - coords.rank) * 8 + coords.file;
}

/// Converts a 0-63 square index to (file, rank) tuple
({int file, int rank}) squareIndexToFileRank(int index) {
  if (index < 0 || index > 63) {
    throw ArgumentError('Invalid square index: $index');
  }
  return (file: index % 8, rank: 7 - (index ~/ 8));
}

/// Converts (file, rank) to 0-63 square index
int fileRankToSquareIndex(int file, int rank) {
  if (file < 0 || file > 7 || rank < 0 || rank > 7) {
    throw ArgumentError('Invalid file/rank: $file/$rank');
  }
  return (7 - rank) * 8 + file;
}

/// Converts algebraic square (e.g., "e4") to 0-based file and rank
/// Returns (file, rank) where file 0=a, 1=b... and rank 0=rank1, 7=rank8
(int file, int rank) algebraicToFileRank(String square) {
  final coords = coordinatesToIndex(square);
  if (coords == null) throw ArgumentError('Invalid square: $square');
  return (coords.file, coords.rank);
}

/// Converts a FEN square to (file, rank) where file 0=a, rank 0=1st rank
(int file, int rank) fenSquareToFileRank(String square) {
  return algebraicToFileRank(square);
}

/// Converts (file, rank) to algebraic notation
String fileRankToAlgebraic(int file, int rank) {
  if (file < 0 || file > 7 || rank < 0 || rank > 7) {
    throw ArgumentError('Invalid file/rank: $file/$rank');
  }
  final fileChar = String.fromCharCode('a'.codeUnitAt(0) + file);
  final rankChar = (rank + 1).toString();
  return '$fileChar$rankChar';
}

/// Checks if a square is dark
bool isDarkSquare(String square) {
  final coords = coordinatesToIndex(square);
  if (coords == null) return false;
  return (coords.file + coords.rank) % 2 == 1;
}