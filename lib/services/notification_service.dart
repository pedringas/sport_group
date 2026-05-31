import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;

/// Top-level background message handler (required by FCM — must be top-level).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase is already initialized when this is called.
  // System tray notification is shown automatically by FCM for data+notification messages.
  debugPrint('[FCM] Background: ${message.messageId}');
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _messaging = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();
  final _db = FirebaseFirestore.instance;

  static const _channelId = 'sports_groups_main';
  static const _channelName = 'SportGroups';
  static const _channelDesc = 'Notificaciones de grupos y pagos';

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Call once from main() after Firebase.initializeApp().
  Future<void> initialize() async {
    // FCM background messages and local notifications don't work on web
    if (kIsWeb) {
      debugPrint('[FCM] Web platform — skipping native notification setup');
      await _refreshAndSaveToken();
      return;
    }

    // 1. Register background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // 2. Request permission (Android 13+ / iOS)
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint('[FCM] Permission: ${settings.authorizationStatus}');

    // 3. Set up Android foreground notification channel
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.high,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // 4. Initialize flutter_local_notifications
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );

    // 5. Foreground message → show local notification
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    // 6. Background → foreground (app tapped from notification)
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpened);

    // 7. Terminated → opened via notification
    final initial = await _messaging.getInitialMessage();
    if (initial != null) _onMessageOpened(initial);

    // 8. Save FCM token (user might already be logged in — e.g. on hot restart)
    await _refreshAndSaveToken();

    // 9. Auto-refresh token
    _messaging.onTokenRefresh.listen(_persistToken);
  }

  /// Call right after a successful login so the token is persisted immediately.
  Future<void> onUserLoggedIn() async {
    await _refreshAndSaveToken();
  }

  // ── Private ────────────────────────────────────────────────────────────────

  Future<void> _refreshAndSaveToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final token = await _messaging.getToken();
      if (token != null) await _persistToken(token);
    } catch (e) {
      debugPrint('[FCM] Could not get token: $e');
    }
  }

  Future<void> _persistToken(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await _db
          .collection('usuarios')
          .doc(user.uid)
          .update({'fcmToken': token});
      debugPrint('[FCM] Token saved for ${user.uid}');
    } catch (e) {
      debugPrint('[FCM] Error saving token: $e');
    }
  }

  void _onForegroundMessage(RemoteMessage message) {
    final n = message.notification;
    if (n == null) return;

    _localNotifications.show(
      message.hashCode,
      n.title,
      n.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  void _onMessageOpened(RemoteMessage message) {
    // message.data contains: { tipo, pagoId, grupoId }
    // Navigation handled by the router; this is a good place to add deep-link
    // routing in the future.
    debugPrint('[FCM] Opened from notification: ${message.data}');
  }

  void _onLocalNotificationTap(NotificationResponse response) {
    debugPrint('[FCM] Local notification tapped: ${response.payload}');
  }
}
