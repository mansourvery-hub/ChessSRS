import 'package:chess_srs/src/model/common/id.dart';
import 'package:chess_srs/src/model/tv/featured_player.dart';
import 'package:chess_srs/src/model/tv/tv_channel.dart';
import 'package:chess_srs/src/model/user/user.dart';
import 'package:dartchess/dartchess.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'tv_game.freezed.dart';

@freezed
sealed class TvGame with _$TvGame {
  const factory TvGame({
    required GameId id,
    required LightUser user,
    required int? rating,
    Side? side,
  }) = _TvGame;
}

@freezed
sealed class TvGameSnapshot with _$TvGameSnapshot {
  const factory TvGameSnapshot({
    required TvChannel channel,
    required GameId id,
    required Side orientation,
    required FeaturedPlayer player,
    String? fen,
    Move? lastMove,
  }) = _TvGameSnapshot;
}
