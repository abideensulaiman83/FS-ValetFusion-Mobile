// lib/components/notification_bell.dart
//
// The app-bar bell for staff: unread badge, refreshed every 60 s and whenever the app comes back
// to the front; tapping it opens the inbox.
import 'dart:async';
import 'package:flutter/material.dart';
import '../pages/notifications_inbox_page.dart';
import '../services/inbox_service.dart';
import '../theme/app_theme.dart';

class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    InboxController.instance.refresh();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => InboxController.instance.refresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) InboxController.instance.refresh();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: InboxController.instance.unread,
      builder: (context, unread, _) => IconButton(
        tooltip: unread > 0 ? 'Notifications ($unread unread)' : 'Notifications',
        onPressed: () async {
          await Navigator.of(context).push(MaterialPageRoute(
            settings: const RouteSettings(name: '/notifications'),
            builder: (_) => const NotificationsInboxPage(),
          ));
          InboxController.instance.refresh();
        },
        icon: Badge(
          isLabelVisible: unread > 0,
          backgroundColor: AppColors.danger,
          textColor: Colors.white,
          label: Text(unread > 99 ? '99+' : '$unread'),
          child: Icon(unread > 0 ? Icons.notifications_active_rounded : Icons.notifications_none_rounded),
        ),
      ),
    );
  }
}
