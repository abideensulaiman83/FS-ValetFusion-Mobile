// lib/components/undo_step_dialog.dart
//
// "Undo last step" for a ticket the desk moved on by mistake - same dialog and wording as the
// portal (UndoStepDialog.tsx): what goes back, what happens with it, a required reason (it lands
// in the audit log). The server enforces the rules (time limit on deliveries, ticket already
// given to another car) and its message is shown as-is when it refuses.
import 'package:flutter/material.dart';
import '../services/valet_service.dart';
import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';

const _label = {
  'RECEIVED': 'Parked',
  'REQUESTED': 'Requested',
  'ONTHEWAY': 'On the way',
  'ARRIVED': 'At lobby',
  'DELIVERED': 'Delivered',
};
const _backTo = {
  'REQUESTED': 'Parked',
  'ONTHEWAY': 'Requested',
  'ARRIVED': 'On the way',
  'DELIVERED': 'At lobby',
};
const _effect = {
  'REQUESTED': 'The request, its charge and remarks are cleared. The car shows as parked again.',
  'ONTHEWAY': 'The driver\'s job is cancelled (they get a notification) and the car goes back to its slot. '
      'The ticket waits for dispatch again.',
  'ARRIVED': 'The car shows as on the way again; it can be marked arrived later.',
  'DELIVERED': 'The ticket is taken out of the pad again and the car shows at the lobby, not handed over. '
      'Only possible while the ticket has not been given to another car.',
};
const _quick = ['Pressed by mistake', 'Wrong ticket', 'Wrong driver', 'Guest changed mind', 'Car not handed over yet'];

/// Shows the dialog; returns the server's message when the step was undone, null otherwise.
Future<String?> showUndoStepDialog(
  BuildContext context, {
  required int parkingVehicleId,
  required String ticketNo,
  String? plateNo,
  required String status,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _UndoStepDialog(
      parkingVehicleId: parkingVehicleId,
      ticketNo: ticketNo,
      plateNo: plateNo,
      status: status,
    ),
  );
}

class _UndoStepDialog extends StatefulWidget {
  const _UndoStepDialog({required this.parkingVehicleId, required this.ticketNo, this.plateNo, required this.status});

  final int parkingVehicleId;
  final String ticketNo;
  final String? plateNo;
  final String status;

  @override
  State<_UndoStepDialog> createState() => _UndoStepDialogState();
}

class _UndoStepDialogState extends State<_UndoStepDialog> {
  final _reason = TextEditingController();
  bool _busy = false;
  String _error = '';

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reason.text.trim();
    if (reason.length < 3 || _busy) return;
    setState(() { _busy = true; _error = ''; });
    try {
      final message = await ValetService().undoLastStep(widget.parkingVehicleId, reason);
      if (mounted) Navigator.of(context).pop(message);
    } catch (e) {
      if (mounted) setState(() { _busy = false; _error = e.toString().replaceAll('Exception: ', ''); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final vf = context.vf;
    final from = _label[widget.status] == null ? widget.status : tr(context, _label[widget.status]!);
    final toKey = _backTo[widget.status];
    final to = toKey == null ? null : tr(context, toKey);
    final plate = widget.plateNo == null || widget.plateNo!.isEmpty ? '' : ' · ${widget.plateNo}';
    return AlertDialog(
      title: Row(children: [
        Icon(Icons.undo, color: vf.warning),
        const SizedBox(width: 8),
        Text(tr(context, 'Undo last step')),
      ]),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr(context, 'Ticket {no}: move it back from {from} to {to}?', {'no': '${widget.ticketNo}$plate', 'from': from, 'to': to ?? '-'}),
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(tr(context, to == null ? 'This ticket has no step to undo.' : _effect[widget.status]!),
                style: TextStyle(fontSize: 13, color: vf.textSecondary)),
            const SizedBox(height: 14),
            Text(tr(context, 'Reason (saved in the audit log)'), style: TextStyle(fontSize: 12, color: vf.textSecondary)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _quick
                  .map((q) => ActionChip(
                        label: Text(tr(context, q), style: const TextStyle(fontSize: 12)),
                        onPressed: _busy ? null : () => setState(() => _reason.text = tr(context, q)),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _reason,
              enabled: !_busy,
              maxLength: 200,
              decoration: InputDecoration(hintText: tr(context, 'Why is this step being undone?'), isDense: true),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _submit(),
            ),
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(_error, style: TextStyle(color: vf.danger, fontSize: 13)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(), child: Text(tr(context, 'Keep as is'))),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: vf.warning, foregroundColor: AppColors.ink),
          onPressed: to == null || _busy || _reason.text.trim().length < 3 ? null : _submit,
          icon: _busy
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.undo, size: 18),
          label: Text(tr(context, 'Back to {step}', {'step': to ?? '-'})),
        ),
      ],
    );
  }
}
