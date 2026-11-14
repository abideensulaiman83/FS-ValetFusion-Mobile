// lib/components/ticket_scan.dart
//
// Camera scan of a valet ticket, shared by the Desk, Driver, Shop and Guest screens. The code on
// a ticket is usually the plain ticket number, but the guest tracking QR (/track/CODE/TICKET) and
// links with a ?ticket= parameter carry it too - all of them resolve to the bare ticket number.
import 'package:material_ui/material_ui.dart';
import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';
import 'barcode_scanner_page.dart';

final RegExp _keyTagPrefix = RegExp(r'^(?:HOOK|KEY)[\s\-_:#]*[A-Z0-9]', caseSensitive: false);

/// The ticket number in a scanned code, or null if the code isn't a ticket (key tag, other URL).
String? parseScannedTicket(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;

  final uri = Uri.tryParse(text);
  if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
    for (final key in const ['ticket', 'ticketNo', 'ticket_no', 't']) {
      final v = uri.queryParameters[key]?.trim();
      if (v != null && v.isNotEmpty) return v;
    }
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    final i = segments.indexOf('track');
    if (i >= 0 && segments.length > i + 2) return segments[i + 2].trim();
    return null;
  }

  // A key hook QR scanned by mistake would otherwise come back as "ticket not found".
  if (_keyTagPrefix.hasMatch(text)) return null;
  return text;
}

/// Opens the camera on a ticket; returns its ticket number, or null if cancelled / not a ticket.
Future<String?> scanTicket(BuildContext context, {String title = 'Scan Ticket Barcode'}) async {
  final raw = await Navigator.of(context).push<String>(MaterialPageRoute(
    builder: (_) => BarcodeScannerPage(
      title: tr(context, title),
      hint: tr(context, 'Point the camera at the ticket QR code or barcode'),
    ),
  ));
  if (raw == null || raw.trim().isEmpty) return null;
  final ticket = parseScannedTicket(raw);
  if (ticket == null && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(tr(context, '"{code}" is not a ticket code', {'code': raw.length > 30 ? '${raw.substring(0, 30)}…' : raw})),
      backgroundColor: context.vf.danger,
    ));
  }
  return ticket;
}
