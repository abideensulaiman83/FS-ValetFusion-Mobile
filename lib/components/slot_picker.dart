// lib/components/slot_picker.dart
//
// "Where do I park this car?" - loads the free valet slots (nearest first, in the building ->
// floor -> area -> slot order the property set up) and pre-selects the first one, so the driver
// just drives there. They can pick another slot, or type a bay by hand when the property has no
// layout configured (or the suggested spot is physically blocked).
import 'package:flutter/material.dart';
import '../services/valet_service.dart';
import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';

class SlotPicker extends StatefulWidget {
  /// Called with the chosen slot, or null when the user switched to typing the bay by hand.
  final ValueChanged<AvailableSlot?> onChanged;
  final TextEditingController bayController;

  const SlotPicker({super.key, required this.onChanged, required this.bayController});

  @override
  State<SlotPicker> createState() => SlotPickerState();
}

class SlotPickerState extends State<SlotPicker> {
  final ValetService _valetService = ValetService();
  List<AvailableSlot> _slots = [];
  AvailableSlot? _selected;
  bool _loading = true;
  bool _manual = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    reload();
  }

  /// Re-fetch free slots - e.g. after the server said the chosen one was just taken.
  Future<void> reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final slots = await _valetService.fetchAvailableSlots(limit: 100);
      if (!mounted) return;
      setState(() {
        _slots = slots;
        final keep = _selected == null ? null : slots.where((s) => s.slotId == _selected!.slotId).firstOrNull;
        _selected = keep ?? (slots.isNotEmpty ? slots.first : null);
        if (slots.isEmpty) _manual = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _manual = true;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
    widget.onChanged(_manual ? null : _selected);
  }

  void _setManual(bool manual) {
    setState(() => _manual = manual);
    widget.onChanged(manual ? null : _selected);
  }

  Future<void> _chooseOther() async {
    final picked = await showModalBottomSheet<AvailableSlot>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (_, scroll) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 8),
              child: Text(tr(context, _slots.length == 1 ? '{n} free slot · nearest first' : '{n} free slots · nearest first', {'n': _slots.length}),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
            Expanded(
              child: ListView.separated(
                controller: scroll,
                itemCount: _slots.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final s = _slots[i];
                  final selected = s.slotId == _selected?.slotId;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: selected ? context.vf.success : context.vf.line,
                      foregroundColor: selected ? context.vf.onColor : context.vf.textPrimary,
                      child: const Icon(Icons.local_parking, size: 20),
                    ),
                    title: Text(tr(context, 'Slot {no}', {'no': s.slotNumber}), style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: s.where.isEmpty ? null : Text(s.where),
                    trailing: i == 0 ? Chip(label: Text(tr(context, 'Nearest')), visualDensity: VisualDensity.compact) : null,
                    onTap: () => Navigator.of(sheetContext).pop(s),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
    if (picked != null) {
      setState(() => _selected = picked);
      widget.onChanged(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(children: [
          const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 12),
          Text(tr(context, 'Finding the nearest free slot...')),
        ]),
      );
    }

    if (_manual) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_slots.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _error != null
                    ? tr(context, 'Could not load free slots ({error}) - type the bay instead.', {'error': _error})
                    : tr(context, 'No free slot in the parking layout - type where you parked.'),
                style: TextStyle(fontSize: 12, color: context.vf.warning),
              ),
            ),
          TextField(
            controller: widget.bayController,
            decoration: InputDecoration(
              labelText: tr(context, 'Bay / spot *'),
              hintText: tr(context, 'e.g. B2-14'),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
          Row(
            children: [
              if (_slots.isNotEmpty)
                TextButton.icon(
                  onPressed: () => _setManual(false),
                  icon: const Icon(Icons.local_parking, size: 18),
                  label: Text(tr(context, 'Pick from free slots')),
                ),
              const Spacer(),
              TextButton.icon(
                onPressed: reload,
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(tr(context, 'Refresh')),
              ),
            ],
          ),
        ],
      );
    }

    final s = _selected!;
    final isNearest = _slots.isNotEmpty && _slots.first.slotId == s.slotId;
    final vf = context.vf;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: vf.successSoft,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: vf.successSoft, width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: vf.success, borderRadius: BorderRadius.circular(10)),
                child: FittedBox(
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(s.slotNumber,
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr(context, isNearest ? 'Park here - nearest free slot' : 'Park here'),
                        style: TextStyle(fontSize: 12, color: vf.success, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(tr(context, 'Slot {no}', {'no': s.slotNumber}), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    if (s.where.isNotEmpty)
                      Text(s.where, style: TextStyle(fontSize: 13, color: vf.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            TextButton(
              onPressed: _chooseOther,
              child: Text(tr(context, 'Choose another ({n} free)', {'n': _slots.length})),
            ),
            const Spacer(),
            TextButton(onPressed: () => _setManual(true), child: Text(tr(context, 'Type bay instead'))),
          ],
        ),
      ],
    );
  }
}
