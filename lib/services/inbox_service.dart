// lib/services/inbox_service.dart
//
// The bell's inbox (plan §2.9) - the same in-app notifications the portal bell shows, from
// NotificationController: GET /api/v1/notifications?limit= -> {unread, items:[{id, type,
// severity INFO|WARNING|CRITICAL, title, body, link, read, createdAt}]}, GET .../unread-count,
// POST .../{id}/read, POST .../read-all. (Push notifications are NotificationService; this is the
// list a user can come back to.) InboxController keeps the unread count for the app-bar badge.
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'authentication_service.dart';
import 'plan_service.dart' show apiErrorFrom;
import 'secure_store.dart';

class InboxItem {
  final int id;
  final String? type;
  final String severity; // INFO, WARNING, CRITICAL
  final String title;
  final String? body;
  final String? link; // portal path, e.g. /dashboard?q=TICKET
  final bool read;
  final DateTime? createdAt;

  const InboxItem({
    required this.id,
    this.type,
    required this.severity,
    required this.title,
    this.body,
    this.link,
    required this.read,
    this.createdAt,
  });

  factory InboxItem.fromJson(Map<String, dynamic> j) => InboxItem(
        id: (j['id'] as num).toInt(),
        type: j['type'] as String?,
        severity: (j['severity'] as String?) ?? 'INFO',
        title: (j['title'] as String?) ?? '',
        body: j['body'] as String?,
        link: j['link'] as String?,
        read: j['read'] == true,
        createdAt: j['createdAt'] is String ? DateTime.tryParse(j['createdAt'] as String) : null,
      );

  InboxItem asRead() => InboxItem(
      id: id, type: type, severity: severity, title: title, body: body, link: link, read: true, createdAt: createdAt);

  /// The ticket this notification is about, from the link's ?q= / ?ticketNo= (or the body's
  /// "Ticket ABC123"); null when it is not about a ticket.
  String? get ticketNo {
    final l = link;
    if (l != null && l.isNotEmpty) {
      try {
        final uri = Uri.parse(l.startsWith('/') ? 'https://x$l' : l);
        final q = uri.queryParameters['q'] ?? uri.queryParameters['ticketNo'] ?? uri.queryParameters['ticket'];
        if (q != null && q.trim().isNotEmpty) return q.trim();
      } catch (_) {}
    }
    final m = RegExp(r'\bTicket\s+([A-Za-z0-9-]+)').firstMatch(body ?? '');
    return m?.group(1);
  }
}

class InboxPage {
  final int unread;
  final List<InboxItem> items;
  const InboxPage(this.unread, this.items);
}

class InboxService {
  static const String _base = '${AuthenticationService.apiBaseUrl}/v1/notifications';
  static const Duration _timeout = Duration(seconds: 20);

  Future<Map<String, String>> _headers() async {
    final token = await SecureStore.token();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<InboxPage> list({int limit = 50}) async {
    final r = await http.get(Uri.parse('$_base?limit=$limit'), headers: await _headers()).timeout(_timeout);
    if (r.statusCode != 200) throw apiErrorFrom(r);
    final data = jsonDecode(r.body) as Map<String, dynamic>;
    final items = ((data['items'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => InboxItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return InboxPage((data['unread'] as num?)?.toInt() ?? items.where((i) => !i.read).length, items);
  }

  Future<int> unreadCount() async {
    final r = await http.get(Uri.parse('$_base/unread-count'), headers: await _headers()).timeout(_timeout);
    if (r.statusCode != 200) throw apiErrorFrom(r);
    return ((jsonDecode(r.body) as Map<String, dynamic>)['unread'] as num?)?.toInt() ?? 0;
  }

  Future<void> markRead(int id) async {
    final r = await http.post(Uri.parse('$_base/$id/read'), headers: await _headers()).timeout(_timeout);
    if (r.statusCode != 204 && r.statusCode != 200 && r.statusCode != 404) throw apiErrorFrom(r);
  }

  Future<void> markAllRead() async {
    final r = await http.post(Uri.parse('$_base/read-all'), headers: await _headers()).timeout(_timeout);
    if (r.statusCode != 200) throw apiErrorFrom(r);
  }
}

/// Unread count shared by every bell on screen.
class InboxController {
  InboxController._();
  static final InboxController instance = InboxController._();

  final ValueNotifier<int> unread = ValueNotifier<int>(0);
  final InboxService service = InboxService();
  Future<void>? _refreshing;

  Future<void> refresh() => _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);

  Future<void> _doRefresh() async {
    try {
      unread.value = await service.unreadCount();
    } catch (_) {
      // Offline - keep the last count.
    }
  }

  void clear() => unread.value = 0;
}
