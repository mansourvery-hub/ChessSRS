import 'package:equatable/equatable.dart';

/// A chess position keyed deterministically from its full FEN state so that
/// repetition semantics, castling rights and en-passant state are preserved.
class PositionKey extends Equatable {
  const PositionKey._(this.fen);

  factory PositionKey.fromFen(String fen) {
    final trimmed = fen.trim().split(RegExp(r'\s+')).take(4).join(' ');
    return PositionKey._(trimmed);
  }

  final String fen;

  @override
  bool get stringify => true;

  @override
  List<Object?> get props => [fen];
}