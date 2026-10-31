// lib/pages/notifications_inbox_page.dart
//
// Staff inbox: the same notifications as the portal bell, newest first. Severity colour on the
// left, time, unread in bold. Tapping one marks it read and, when it is about a ticket and this
// user works the desk, opens that ticket on the desk.
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_strings.dart';
import '../services/authentication_service.dart';
import '../services/desk_links.dart';
import '../services/inbox_service.dart';
import '../theme/app_theme.dart';

class NotificationsInboxPage extends StatefulWidget {
  const NotificationsInboxPage({super.key});

  @override
  State<NotificationsInboxPage> createState() => _NotificationsInboxPageState();
}

class _NotificationsInboxPageState extends State<NotificationsInboxPage> with WidgetsBindingObserver {
  final _service = InboxController.instance.service;
  List<InboxItem> _items = const [];
  bool _loading = true;
  String? _error;
  bool _canOpenDesk = false;
  Timer? _timer;

  static const _deskRoles = {'LOBBY', 'KEY_CONTROLLER', 'VALET_STAFF', 'LOCATION_ADMIN', 'SUPER_ADMIN'};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadRoles();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => _load(quiet: true));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load(quiet: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _loadRoles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userStr = prefs.getString(AuthenticationService.userKey);
      if (userStr == null) return;
      final roles = List<String>.from((jsonDecode(userStr) as Map<String, dynamic>)['roles'] ?? const []);
      // Drivers' desk is the driver flow - it has no ticket lookup to open into.
      final desk = roles.any(_deskRoles.contains) && !roles.contains('DRIVER');
      if (mounted) setState(() => _canOpenDesk = desk);
    } catch (_) {}
  }

  Future<void> _load({bool quiet = false}) async {
    if (!quiet) setState(() => _loading = true);
    try {
      final page = await _service.list(limit: 50);
      InboxController.instance.unread.value = page.unread;
      if (mounted) {
        setState(() {
          _items = page.items;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted && !quiet) setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted && !quiet) setState(() => _loading = false);
    }
  }

  Future<void> _markAll() async {
    try {
      await _service.markAllRead();
      InboxController.instance.unread.value = 0;
      if (mounted) setState(() => _items = _items.map((i) => i.asRead()).toList());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: context.vf.danger));
      }
    }
  }

  Future<void> _open(InboxItem item) async {
    if (!item.read) {
      setState(() => _items = _items.map((i) => i.id == item.id ? i.asRead() : i).toList());
      final u = InboxController.instance.unread.value;
      InboxController.instance.unread.value = u > 0 ? u - 1 : 0;
      _service.markRead(item.id).catchError((_) {});
    }
    final ticket = item.ticketNo;
    if (ticket != null && _canOpenDesk && mounted) {
      DeskLinks.openTicket(Navigator.of(context), ticket);
    }
  }

  Color _severityColor(String severity) {
    switch (severity) {
      case 'CRITICAL':
        return context.vf.danger;
      case 'WARNING':
        return context.vf.warning;
      default:
        return context.vf.live;
    }
  }

  IconData _severityIcon(String severity) {
    switch (severity) {
      case 'CRITICAL':
        return Icons.error_rounded;
      case 'WARNING':
        return Icons.warning_amber_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  String _when(DateTime? t) {
    if (t == null) return '';
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return tr(context, 'just now');
    if (d.inMinutes < 60) return tr(context, '{n} min ago', {'n': d.inMinutes});
    if (d.inHours < 24) return tr(context, '{n} h ago', {'n': d.inHours});
    return DateFormat('d MMM, HH:mm').format(t);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final anyUnread = _items.any((i) => !i.read);
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, 'Notifications')),
        actions: [
          if (anyUnread) TextButton(onPressed: _markAll, child: Text(tr(context, 'Mark all read'))),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(quiet: false),
        child: _loading && _items.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _error != null && _items.isEmpty
                ? ListView(children: [
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(_error!, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
                    ),
                  ])
                : _items.isEmpty
                    ? ListView(children: [
                        const SizedBox(height: 80),
                        Icon(Icons.notifications_none_rounded, size: 48, color: context.vf.textSecondary),
                        const SizedBox(height: 12),
                        Text(tr(context, 'No notifications yet'), textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(tr(context, 'Alerts such as a guest waiting for a driver show up here.'),
                            textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
                      ])
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) => _tile(_items[i], theme),
                      ),
      ),
    );
  }

  Widget _tile(InboxItem item, ThemeData theme) {
    final color = _severityColor(item.severity);
    final ticket = item.ticketNo;
    return Material(
      color: item.read ? context.vf.card : context.vf.card2,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _open(item),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: context.vf.line),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 5,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: const BorderRadiusDirectional.horizontal(start: Radius.circular(10)),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(_severityIcon(item.severity), color: color, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Expanded(
                                  child: Text(item.title,
                                      style: theme.textTheme.titleSmall?.copyWith(
                                          fontWeight: item.read ? FontWeight.w500 : FontWeight.w700)),
                                ),
                                if (!item.read)
                                  Container(
                                    width: 8,
                                    height: 8,
                                    margin: const EdgeInsetsDirectional.only(start: 6),
                                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                                  ),
                              ]),
                              if (item.body != null && item.body!.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(item.body!, style: theme.textTheme.bodyMedium),
                              ],
                              const SizedBox(height: 6),
                              Row(children: [
                                Text(_when(item.createdAt), style: theme.textTheme.bodySmall),
                                if (ticket != null && _canOpenDesk) ...[
                                  const Spacer(),
                                  Text(tr(context, 'Open ticket {no}', {'no': ticket}),
                                      style: theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.primary, fontWeight: FontWeight.w700)),
                                  Icon(Icons.chevron_right_rounded, size: 16, color: theme.colorScheme.primary),
                                ],
                              ]),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
