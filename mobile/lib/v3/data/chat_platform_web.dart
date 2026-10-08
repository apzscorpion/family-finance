import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/services.dart';

void Function(String senderId)? _webOnTapSender;
const String _baseTitle = 'Family Spend Tracker';

String get chatNotificationPermissionStatus {
  try {
    if (!globalContext.has('Notification')) return 'unsupported';
    final notifClass = globalContext['Notification'];
    if (notifClass == null || notifClass.isUndefinedOrNull) {
      return 'unsupported';
    }
    final perm = (notifClass as JSObject)['permission'];
    if (perm != null && !perm.isUndefinedOrNull) {
      return (perm as JSString).toDart;
    }
  } catch (_) {}
  return 'unsupported';
}

bool get _isDocumentHidden {
  try {
    final doc = globalContext['document'];
    if (doc != null && !doc.isUndefinedOrNull) {
      final hidden = (doc as JSObject)['hidden'];
      if (hidden != null && !hidden.isUndefinedOrNull) {
        return (hidden as JSBoolean).toDart;
      }
    }
  } catch (_) {}
  return false;
}

Future<void> initChatNotifications({
  void Function(String senderId)? onTapSender,
}) async {
  if (onTapSender != null) {
    _webOnTapSender = onTapSender;
  }
}

Future<bool> requestChatNotificationPermission({
  void Function(String senderId)? onTapSender,
}) async {
  if (onTapSender != null) {
    _webOnTapSender = onTapSender;
  }
  try {
    if (!globalContext.has('Notification')) return false;
    final notifClass = globalContext['Notification'] as JSObject;
    final current = chatNotificationPermissionStatus;
    if (current == 'granted') {
      _playWebChime(isPoke: false);
      return true;
    }
    final result = notifClass.callMethod('requestPermission'.toJS);
    if (result != null && !result.isUndefinedOrNull) {
      final permJs = await (result as JSPromise<JSAny?>).toDart;
      final perm =
          permJs != null && !permJs.isUndefinedOrNull
              ? (permJs as JSString).toDart
              : chatNotificationPermissionStatus;
      if (perm == 'granted') {
        _playWebChime(isPoke: false);
        return true;
      }
    }
  } catch (_) {}
  return chatNotificationPermissionStatus == 'granted';
}

void updateChatUnreadBadge(int unreadCount, {String? latestSender}) {
  try {
    final doc = globalContext['document'];
    if (doc == null || doc.isUndefinedOrNull) return;
    final docObj = doc as JSObject;
    if (unreadCount <= 0) {
      docObj['title'] = _baseTitle.toJS;
    } else if (latestSender != null && latestSender.isNotEmpty) {
      docObj['title'] = '($unreadCount) 💬 $latestSender · $_baseTitle'.toJS;
    } else {
      docObj['title'] = '($unreadCount) $_baseTitle'.toJS;
    }
  } catch (_) {}
}

void _playWebChime({required bool isPoke}) {
  try {
    JSFunction? audioCtxCtor;
    if (globalContext.has('AudioContext')) {
      audioCtxCtor = globalContext['AudioContext'] as JSFunction?;
    } else if (globalContext.has('webkitAudioContext')) {
      audioCtxCtor = globalContext['webkitAudioContext'] as JSFunction?;
    }
    if (audioCtxCtor == null) return;

    final ctx = audioCtxCtor.callAsConstructor<JSObject>();
    final now = ((ctx['currentTime'] as JSNumber?)?.toDartDouble) ?? 0.0;

    final notes = isPoke
        ? const [(0.0, 659.25, 0.11), (0.13, 880.0, 0.11), (0.26, 1046.5, 0.18)]
        : const [(0.0, 587.33, 0.10), (0.11, 880.0, 0.16)];

    for (final (offset, freq, dur) in notes) {
      final osc = ctx.callMethod<JSObject>('createOscillator'.toJS);
      final gain = ctx.callMethod<JSObject>('createGain'.toJS);
      osc['type'] = 'sine'.toJS;
      (osc['frequency'] as JSObject).callMethod(
        'setValueAtTime'.toJS,
        freq.toJS,
        (now + offset).toJS,
      );

      final gainParam = gain['gain'] as JSObject;
      gainParam.callMethod('setValueAtTime'.toJS, 0.001.toJS, (now + offset).toJS);
      gainParam.callMethod(
        'exponentialRampToValueAtTime'.toJS,
        (isPoke ? 0.22 : 0.14).toJS,
        (now + offset + 0.02).toJS,
      );
      gainParam.callMethod(
        'exponentialRampToValueAtTime'.toJS,
        0.0001.toJS,
        (now + offset + dur).toJS,
      );

      osc.callMethod('connect'.toJS, gain);
      gain.callMethod('connect'.toJS, ctx['destination']);
      osc.callMethod('start'.toJS, (now + offset).toJS);
      osc.callMethod('stop'.toJS, (now + offset + dur + 0.02).toJS);
    }
  } catch (_) {}
}

void _showBrowserNotification({
  required String senderId,
  required String title,
  required String body,
}) {
  try {
    if (chatNotificationPermissionStatus != 'granted') return;
    final notifCtor = globalContext['Notification'] as JSFunction?;
    if (notifCtor == null) return;

    final options = JSObject();
    options['body'] = body.toJS;
    options['icon'] = 'icons/Icon-192.png'.toJS;
    options['badge'] = 'icons/Icon-192.png'.toJS;
    options['tag'] = 'dm_$senderId'.toJS;
    options['renotify'] = true.toJS;

    final notif = notifCtor.callAsConstructor<JSObject>(title.toJS, options);
    notif['onclick'] = ((JSAny? _) {
      try {
        globalContext.callMethod('focus'.toJS);
        notif.callMethod('close'.toJS);
      } catch (_) {}
      _webOnTapSender?.call(senderId);
    }).toJS;
  } catch (_) {}
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
    await HapticFeedback.vibrate();
  } catch (_) {}

  _playWebChime(isPoke: isPoke);

  if (showSystemNotification || _isDocumentHidden || isPoke) {
    final title = isPoke ? '👋 $senderName poked you!' : '💬 $senderName';
    final preview = isPoke
        ? (body.isNotEmpty && body != '👋 Poked you!'
            ? body
            : 'Tap to open chat & reply')
        : body;
    _showBrowserNotification(
      senderId: senderId,
      title: title,
      body: preview,
    );
  }
}