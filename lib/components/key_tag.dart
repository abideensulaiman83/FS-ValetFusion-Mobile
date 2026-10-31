// lib/components/key_tag.dart
//
// Key tag QR: every hook on the key board carries a QR with its number, as plain text - "HOOK-17",
// "HOOK 17", "H17" or just "17". Scanning it when hanging the key sets the car's key holder
// (no typing), and scanning the tag on the key at handover checks it is the right car's key.
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'barcode_scanner_page.dart';

final RegExp _tagPattern = RegExp(r'^(?:HOOK|KEY|H)?[\s\-_:#]*([A-Z0-9]{1,12})$');

/// The hook number in a scanned key tag, or null if the code isn't a key tag (e.g. a URL).
String? parseKeyTag(String raw) {
  final m = _tagPattern.firstMatch(raw.trim().toUpperCase());
  if (m == null) return null;
  final value = m.group(1)!;
  // "017" and "17" are the same hook.
  return RegExp(r'^\d+$').hasMatch(value) ? int.parse(value).toString() : value;
}

/// True when a scanned tag and the car's recorded key holder name the same hook.
bool keyTagMatches(String scanned, String? recorded) {
  if (recorded == null || recorded.trim().isEmpty) return false;
  final a = parseKeyTag(scanned), b = parseKeyTag(recorded);
  return a != null && a == b;
}

/// Opens the camera on a key tag; returns the hook number, or null if cancelled / not a tag.
Future<String?> scanKeyTag(BuildContext context) async {
  final raw = await Navigator.of(context).push<String>(MaterialPageRoute(
    builder: (_) => const BarcodeScannerPage(title: 'Scan Key Tag', hint: 'Point the camera at the QR on the key tag'),
  ));
  if (raw == null || raw.trim().isEmpty) return null;
  final tag = parseKeyTag(raw);
  if (tag == null && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('"${raw.length > 30 ? '${raw.substring(0, 30)}…' : raw}" is not a key tag'),
      backgroundColor: AppColors.danger,
    ));
  }
  return tag;
}

/// Handover check: scan the tag on the key in hand and compare it with the car's key holder.
/// Shows the result (a warning on mismatch) and returns true only on a match.
Future<bool> verifyKeyTag(BuildContext context, {required String? expected, required String ticketNo}) async {
  final tag = await scanKeyTag(context);
  if (tag == null || !context.mounted) return false;
  final hasExpected = expected != null && expected.trim().isNotEmpty;
  final ok = hasExpected && keyTagMatches(tag, expected);
  final again = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: Icon(ok ? Icons.verified_rounded : Icons.warning_amber_rounded,
          color: ok ? AppColors.success : (hasExpected ? AppColors.danger : AppColors.warning), size: 40),
      title: Text(ok ? 'Right key' : (hasExpected ? 'Wrong key?' : 'No key hook recorded')),
      content: Text(
        ok
            ? 'Key tag $tag matches ticket $ticketNo.'
            : hasExpected
                ? 'This key is from hook $tag, but ticket $ticketNo\'s key should be on hook ${expected.trim()}. '
                    'Check you have the right key before handing the car over.'
                : 'Ticket $ticketNo has no key hook on record - the tag reads $tag. Check the plate before handing over.',
        textAlign: TextAlign.center,
      ),
      actions: [
        if (!ok) TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Scan again')),
        ElevatedButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(ok ? 'OK' : 'Close')),
      ],
    ),
  );
  if (again == true && context.mounted) return verifyKeyTag(context, expected: expected, ticketNo: ticketNo);
  return ok;
}

/// Suffix button for a "Key Holder Number" field: scan a tag to fill it in.
class ScanKeyTagSuffix extends StatelessWidget {
  final TextEditingController controller;
  const ScanKeyTagSuffix({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Scan key tag',
      icon: const Icon(Icons.qr_code_scanner),
      onPressed: () async {
        final tag = await scanKeyTag(context);
        if (tag != null) controller.text = tag;
      },
    );
  }
}
