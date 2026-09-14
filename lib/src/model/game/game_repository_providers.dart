import 'package:chess_srs/src/model/auth/auth_controller.dart';
import 'package:chess_srs/src/model/common/id.dart';
import 'package:chess_srs/src/model/game/exported_game.dart';
import 'package:chess_srs/src/model/game/game_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final archivedGameProvider = FutureProvider.autoDispose.family<ExportedGame, GameId>((
  Ref ref,
  GameId id,
) {
  final isLoggedIn = ref.watch(isLoggedInProvider);
  return ref.read(gameRepositoryProvider).getGame(id, withBookmarked: isLoggedIn);
}, name: 'ArchivedGameProvider');
