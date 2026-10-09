import 'package:flutter/services.dart';

import 'notifications_core.dart';

String _ioPermissionStatus = 'default';

String get chatNotificationPermissionStatus => _ioPermissionStatus;

Future<void> initChatNotifications({
  void Function(String senderId)? onTapSender,
}) async {
  if (onTapSender != null) {
    AppNotifications.onTapDirectMessage = onTapSender;
  }
  await AppNotifications.ensureInit();
  final granted = await AppNotifications.hasPermission();
  if (granted) {
    _ioPermissionStatus = 'granted';
  } else {
    final req = await AppNotifications.requestPermission();
    _ioPermissionStatus = req ? 'granted' : 'denied';
  }
}

Future<bool> requestChatNotificationPermission({
  void Function(String senderId)? onTapSender,
}) async {
  if (onTapSender != null) {
    AppNotifications.onTapDirectMessage = onTapSender;
  }
  await AppNotifications.ensureInit();
  final granted = await AppNotifications.requestPermission();
  _ioPermissionStatus = granted ? 'granted' : 'denied';
  return granted;
}

void updateChatUnreadBadge(int unreadCount, {String? latestSender}) {
  // Android unread counts are surfaced via system notifications and in-app badges.
}

Future<void> notifyIncomingChat({
  required String messageId,
  required String senderId,
  required String senderName,
  required String body,
  bool isPoke = false,
  bool showSystemNotification = true,
}) async {
  try {
    if (isPoke) {
      await HapticFeedback.heavyImpact();
      await Future<void>.delayed(const Duration(milliseconds: 140));
      await HapticFeedback.vibrate();
      await Future<void>.delayed(const Duration(milliseconds: 140));
      await HapticFeedback.heavyImpact();
    } else {
      await HapticFeedback.mediumImpact();
    }
  } catch (_) {}

  if (showSystemNotification) {
    await AppNotifications.showDirectMessage(
      messageId: messageId,
      senderId: senderId,
      senderName: senderName,
      body: body,
      isPoke: isPoke,
    );
  }
}
Future<void> startChatBackgroundLink() => AppNotifications.startChatLink();

Future<void> stopChatBackgroundLink() => AppNotifications.stopChatLink();
