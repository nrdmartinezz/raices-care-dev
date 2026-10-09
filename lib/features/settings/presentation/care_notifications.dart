import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

import '../../../app/router.dart';
import '../../../core/api/api_config.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../../auth/data/auth_repository.dart';
import '../data/user_settings_repository.dart';

const _channelId = 'garden_care';

/// Records each open, keeps the device token current, and shows care
/// notifications while the app is in front. A tap opens Chores.
class CareNotifications extends ConsumerStatefulWidget {
  const CareNotifications({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<CareNotifications> createState() => _CareNotificationsState();
}

class _CareNotificationsState extends ConsumerState<CareNotifications>
    with WidgetsBindingObserver {
  final _plugin = FlutterLocalNotificationsPlugin();
  StreamSubscription<RemoteMessage>? _foreground;
  StreamSubscription<RemoteMessage>? _opened;
  StreamSubscription<String>? _tokens;
  var _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(authStatusProvider) == AuthStatus.signedIn) {
        _start();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _foreground?.cancel();
    _opened?.cancel();
    _tokens?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        ref.read(authStatusProvider) == AuthStatus.signedIn) {
      _recordPresence();
      _refreshToken();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authStatusProvider, (previous, next) {
      if (next == AuthStatus.signedIn) {
        _start();
      }
    });
    return widget.child;
  }

  Future<void> _start() async {
    if (_started || !mounted || Firebase.apps.isEmpty) {
      return;
    }
    if (ref.read(authStatusProvider) != AuthStatus.signedIn) {
      return;
    }
    _started = true;
    await _recordPresence();
    if (kIsWeb) {
      return;
    }
    await _refreshToken();
    await _listenForNotifications();
  }

  Future<void> _recordPresence() async {
    if (!usesWorkerApi || Firebase.apps.isEmpty) {
      return;
    }
    if (ref.read(authStatusProvider) != AuthStatus.signedIn) {
      return;
    }
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      final name = zone.identifier.trim();
      await ref
          .read(workerBackendProvider)
          .recordPresence(timezone: name.isEmpty ? null : name);
    } catch (_) {
      // A missed open is recorded the next time the app comes forward.
    }
  }

  Future<void> _refreshToken() async {
    if (kIsWeb || Firebase.apps.isEmpty) {
      return;
    }
    try {
      await ref.read(userSettingsRepositoryProvider).refreshGrantedPushToken();
    } catch (_) {
      // The next resume tries again.
    }
  }

  Future<void> _listenForNotifications() async {
    final messaging = ref.read(firebaseMessagingProvider);
    await messaging.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: false,
      sound: false,
    );
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: _onLocalTap,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            'Garden care',
            description: 'Watering, chores, and check-ins',
            importance: Importance.high,
          ),
        );

    _foreground = FirebaseMessaging.onMessage.listen(_showRemote);
    _opened = FirebaseMessaging.onMessageOpenedApp.listen((_) => _openChores());
    _tokens = messaging.onTokenRefresh.listen((token) {
      if (ref.read(authStatusProvider) != AuthStatus.signedIn) {
        return;
      }
      ref.read(userSettingsRepositoryProvider).registerDeviceToken(token);
    });

    final initial = await messaging.getInitialMessage();
    if (initial != null && mounted) {
      _openChores();
    }
  }

  void _showRemote(RemoteMessage message) {
    final notification = message.notification;
    final title = notification?.title;
    final body = notification?.body;
    if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) {
      return;
    }
    _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Garden care',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: 'chores',
    );
  }

  void _onLocalTap(NotificationResponse response) {
    if (response.payload == 'chores') {
      _openChores();
    }
  }

  void _openChores() {
    ref.read(routerProvider).goNamed(ChoresRoute.name);
  }
}
