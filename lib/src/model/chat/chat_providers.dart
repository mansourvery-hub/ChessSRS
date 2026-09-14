import 'package:chess_srs/src/model/chat/chat.dart';
import 'package:chess_srs/src/model/chat/chat_mixin.dart';
import 'package:chess_srs/src/model/game/game_controller.dart';
import 'package:chess_srs/src/model/study/study_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A provider that gets the current chat state
final chatProvider = FutureProvider.autoDispose.family<ChatState?, ChatOptions>(
  (ref, options) => switch (options) {
    GameChatOptions(:final id) => ref.watch(
      gameControllerProvider(id).selectAsync((state) => state.chatState),
    ),
    StudyChatOptions(:final options) => ref.watch(
      studyControllerProvider(options).selectAsync((state) => state.chatState),
    ),
  },
  name: 'ChatProvider',
);

/// A provider that gets the [ChatMixin] notifier for the given chat.
final chatNotifierProvider = Provider.autoDispose.family<ChatMixin, ChatOptions>(
  (ref, options) => ref.read(switch (options) {
    GameChatOptions(:final id) => gameControllerProvider(id).notifier,
    StudyChatOptions(:final options) => studyControllerProvider(options).notifier,
  }),
  name: 'ChatNotifierProvider',
);

/// A provider that gets the chat unread messages
final chatUnreadProvider = FutureProvider.autoDispose.family<int, ChatOptions>((
  Ref ref,
  ChatOptions options,
) async {
  return (await ref.watch(chatProvider(options).future))?.unreadMessages ?? 0;
}, name: 'ChatUnreadProvider');
