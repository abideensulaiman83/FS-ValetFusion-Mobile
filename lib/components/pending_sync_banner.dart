// lib/components/pending_sync_banner.dart
//
// Shown on the driver, desk and board screens while anything saved without signal is still
// waiting to be sent - parking, photos, ETA answers and the lifecycle steps (request, dispatch,
// arrived, handed over, key holder) - so whoever is holding the phone knows it hasn't gone yet
// (and can push it now). Tap it to see every queued action.
import 'package:flutter/material.dart';
import '../services/offline_queue.dart';
import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';

IconData _iconFor(String type) {
  switch (type) {
    case 'photo':
      return Icons.photo_camera_outlined;
    case 'park_details':
      return Icons.local_parking;
    case 'key_holder':
      return Icons.vpn_key_outlined;
    case 'request':
      return Icons.notifications_active_outlined;
    case 'dispatch':
      return Icons.directions_run;
    case 'arrive':
      return Icons.flag_outlined;
    case 'deliver':
      return Icons.check_circle_outline;
    case 'eta_checkin':
      return Icons.schedule;
    default:
      return Icons.cloud_upload_outlined;
  }
}

String _queuedAt(BuildContext context, String iso) {
  final t = DateTime.tryParse(iso);
  if (t == null) return '';
  final mins = DateTime.now().difference(t).inMinutes;
  final clock = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  return mins < 1
      ? tr(context, 'saved {time} · just now', {'time': clock})
      : tr(context, 'saved {time} · {n} min ago', {'time': clock, 'n': mins});
}

class PendingSyncBanner extends StatelessWidget {
  const PendingSyncBanner({super.key});

  void _showAll(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => ValueListenableBuilder<List<QueuedAction>>(
        valueListenable: OfflineQueue.instance.pending,
        builder: (context, items, _) => SafeArea(
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(items.isEmpty ? tr(context, 'Everything is sent') : tr(context, 'Waiting to send ({n})', {'n': items.length}),
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(tr(context, 'Sent in this order as soon as there is signal. Nothing here is lost if the app closes.'),
                    style: TextStyle(fontSize: 12.5, color: context.vf.textSecondary)),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: items
                        .map((a) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(_iconFor(a.type), color: context.vf.warning),
                              title: Text(a.label),
                              subtitle: Text(_queuedAt(context, a.createdAt)),
                            ))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: items.isEmpty ? null : () => OfflineQueue.instance.flush(),
                  icon: const Icon(Icons.cloud_upload_outlined),
                  label: Text(tr(context, 'Send now')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<QueuedAction>>(
      valueListenable: OfflineQueue.instance.pending,
      builder: (context, items, _) {
        if (items.isEmpty) return const SizedBox.shrink();
        final vf = context.vf;
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Material(
            color: vf.warningSoft,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _showAll(context),
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 6, 10),
                child: Row(
                  children: [
                    Icon(Icons.cloud_off_outlined, color: vf.warning),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tr(context, '{n} waiting to send', {'n': items.length}),
                              style: TextStyle(fontWeight: FontWeight.w700, color: vf.warning)),
                          Text(
                            items.map((a) => a.label).take(3).join(' · ') + (items.length > 3 ? ' …' : ''),
                            style: TextStyle(fontSize: 12, color: vf.warning),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    TextButton(onPressed: () => OfflineQueue.instance.flush(), child: Text(tr(context, 'Send now'))),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
