import 'package:chess_srs/src/model/common/id.dart';
import 'package:chess_srs/src/model/game/player.dart';
import 'package:chess_srs/src/model/user/user.dart';
import 'package:dartchess/dartchess.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'featured_player.freezed.dart';

@freezed
sealed class FeaturedPlayer with _$FeaturedPlayer {
  const FeaturedPlayer._();

  const factory FeaturedPlayer({
    required Side side,
    required String name,
    String? title,
    int? rating,
    int? seconds,
  }) = _FeaturedPlayer;

  FeaturedPlayer withSeconds(int newSeconds) {
    return FeaturedPlayer(
      side: side,
      name: name,
      title: title,
      rating: rating,
      seconds: newSeconds,
    );
  }

  Player get asPlayer => Player(
    user: LightUser(id: UserId(name.toLowerCase()), name: name, title: title),
    rating: rating,
  );
}
