// lib/components/eta_check_in_dialog.dart
//
// "Still on the way?" - shown to the driver every 5 minutes while a car is ONTHEWAY. One tap
// answers it: on time, +5/+10/+15/+20 minutes (the guest's ETA moves by that much), or arrived.
import 'package:flutter/material.dart';
import '../services/valet_service.dart';

class EtaCheckInChoice {
  final int extendMinutes;
  final bool arrived;
  const EtaCheckInChoice.extend(this.extendMinutes) : arrived = false;
  const EtaCheckInChoice.arrived()
      : extendMinutes = 0,
        arrived = true;
}

Future<EtaCheckInChoice?> showEtaCheckInDialog(BuildContext context, TicketStatusResponse d) {
  return showDialog<EtaCheckInChoice>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => _EtaCheckInDialog(delivery: d),
  );
}

class _EtaCheckInDialog extends StatelessWidget {
  final TicketStatusResponse delivery;
  const _EtaCheckInDialog({required this.delivery});

  static const _extensions = [5, 10, 15, 20];

  @override
  Widget build(BuildContext context) {
    final d = delivery;
    final car = [d.vehicleColor, d.vehicleMake, d.vehicleModel].where((s) => s != null && s.isNotEmpty).join(' ');
    final eta = d.etaMinutes;
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      child: AlertDialog(
        icon: Icon(Icons.timer_outlined, size: 36, color: Colors.orange.shade700),
        title: const Text('Still on the way?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Ticket ${d.ticketNo}${d.plateNo != null ? ' · ${d.plateNo}' : ''}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if (car.isNotEmpty)
              Text(car, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 10),
            Text(
              eta == null
                  ? 'The guest is waiting for this car.'
                  : eta <= 0
                      ? 'The guest was told the car would be there by now.'
                      : 'The guest expects the car in about $eta min.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            Text('Need more time?', style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final m in _extensions) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(EtaCheckInChoice.extend(m)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        foregroundColor: Colors.orange.shade800,
                        side: BorderSide(color: Colors.orange.shade300),
                      ),
                      child: Text('+$m', style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  if (m != _extensions.last) const SizedBox(width: 6),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text('minutes', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(const EtaCheckInChoice.extend(0)),
              icon: const Icon(Icons.thumb_up_alt_outlined),
              label: const Text('Yes, on time'),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => Navigator.of(context).pop(const EtaCheckInChoice.arrived()),
              icon: const Icon(Icons.flag_outlined),
              label: const Text("I've arrived with the car"),
            ),
          ],
        ),
      ),
    );
  }
}
