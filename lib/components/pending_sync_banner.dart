// lib/components/pending_sync_banner.dart
//
// Shown on the driver's screen while anything saved without signal is still waiting to be sent,
// so a driver coming up from the basement knows it hasn't gone yet (and can push it now).
import 'package:flutter/material.dart';
import '../services/offline_queue.dart';

class PendingSyncBanner extends StatelessWidget {
  const PendingSyncBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<QueuedAction>>(
      valueListenable: OfflineQueue.instance.pending,
      builder: (context, items, _) {
        if (items.isEmpty) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.cloud_off_outlined, color: Colors.amber.shade900),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${items.length} waiting to send',
                        style: TextStyle(fontWeight: FontWeight.w700, color: Colors.amber.shade900)),
                    Text(
                      items.map((a) => a.label).take(3).join(' · ') + (items.length > 3 ? ' …' : ''),
                      style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              TextButton(onPressed: () => OfflineQueue.instance.flush(), child: const Text('Send now')),
            ],
          ),
        );
      },
    );
  }
}
