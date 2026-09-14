import 'dart:async';

import 'package:chess_srs/src/model/common/id.dart';
import 'package:chess_srs/src/model/message/message_repository.dart';
import 'package:chess_srs/src/model/notifications/notification_service.dart';
import 'package:chess_srs/src/model/notifications/notifications.dart';
import 'package:chess_srs/src/model/user/user_repository.dart';
import 'package:chess_srs/src/tab_navigation.dart';
import 'package:chess_srs/src/view/message/conversation_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A provider for [MessageService].
final messageServiceProvider = Provider<MessageService>((Ref ref) {
  final service = MessageService(ref);
  ref.onDispose(service.dispose);
  return service;
}, name: 'MessageServiceProvider');

class MessageService {
  MessageService(this.ref);

  final Ref ref;

  StreamSubscription<ParsedLocalNotification>? _notificationResponseSubscription;
  StreamSubscription<ReceivedFcmMessage>? _fcmSubscription;

  void start() {
    _fcmSubscription = NotificationService.fcmMessageStream.listen((data) {
      final (message: fcmMessage, :fromBackground) = data;
      switch (fcmMessage) {
        case NewMessageFcmMessage():
          ref.invalidate(contactsProvider);
          ref.invalidate(unreadMessagesProvider);
        case _:
          break;
      }
    });

    _notificationResponseSubscription = NotificationService.responseStream.listen((data) {
      final (_, notification) = data;
      switch (notification) {
        case NewMessageNotification(:final conversationId):
          _onNotificationResponse(conversationId);
        case _:
          break;
      }
    });
  }

  /// Handles a notification response that caused the app to open.
  Future<void> _onNotificationResponse(UserId conversationId) async {
    final user = await ref.read(userRepositoryProvider).getUser(conversationId);

    if (user.kid == true) {
      // If the user is in kid mode, we don't open the conversation screen.
      return;
    }

    final context = ref.read(currentNavigatorKeyProvider).currentContext;
    if (context == null || !context.mounted) return;

    final rootNavState = Navigator.of(context, rootNavigator: true);
    if (rootNavState.canPop()) {
      rootNavState.popUntil((route) => route.isFirst);
    }

    Navigator.of(
      context,
      rootNavigator: true,
    ).push(ConversationScreen.buildRoute(user: user.lightUser));
  }

  void dispose() {
    _fcmSubscription?.cancel();
    _notificationResponseSubscription?.cancel();
  }
}
