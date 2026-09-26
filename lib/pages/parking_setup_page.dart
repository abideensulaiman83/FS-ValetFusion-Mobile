// lib/pages/parking_setup_page.dart
//
// Home screen for the client's SECURITY user (also reachable from the Admin console). After the
// admin has created the buildings/floors on the web portal, security walks the car park and sets
// up the valet space on each floor: add an area ("Zone A", "Ramp side"), add its numbered slots
// in one go (B1-01 .. B1-20), and switch slots off / reserve them when the site changes.
// Drivers are then offered the nearest free slot automatically.
import 'package:flutter/material.dart';
import '../components/confirm_dialog.dart';
import '../services/authentication_service.dart';
import '../services/parking_layout_service.dart';

class ParkingSetupPage extends StatefulWidget {
  /// True when this is the user's home screen (Security) - shows logout instead of back.
  final bool isHome;
  const ParkingSetupPage({super.key, this.isHome = false});

  @override
  State<ParkingSetupPage> createState() => _ParkingSetupPageState();
}

class _ParkingSetupPageState extends State<ParkingSetupPage> {
  final ParkingLayoutService _service = ParkingLayoutService();
  ParkingLayout? _layout;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _layout == null;
      _error = null;
    });
    try {
      final layout = await _service.fetchLayout();
      if (mounted) setState(() => _layout = layout);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? Colors.red.shade700 : Colors.green.shade700,
    ));
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    try {
      await action();
      _snack(done);
      await _load();
    } catch (e) {
      _snack(e.toString().replaceAll('Exception: ', ''), error: true);
    }
  }

  Future<void> _logout() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Log out?',
      message: "You'll need to sign in again to continue.",
      confirmLabel: 'Log out',
      destructive: true,
    );
    if (!ok) return;
    await AuthenticationService().logoutApi();
    if (mounted) Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  // ---- dialogs ----

  Future<void> _addArea(LayoutFloor floor) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('New valet area on ${floor.title}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Area name',
            hintText: 'e.g. Zone A, Near lift',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(controller.text.trim()), child: const Text('Add area')),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await _run(() => _service.addArea(floorId: floor.id, name: name), 'Area "$name" added');
  }

  Future<void> _addSlots(LayoutArea area) async {
    final result = await showDialog<_SlotBatch>(
      context: context,
      builder: (_) => _AddSlotsDialog(area: area),
    );
    if (result == null) return;
    await _run(
      () => _service.addSlots(
        areaId: area.id,
        prefix: result.prefix,
        startNumber: result.start,
        count: result.count,
        slotNumbers: result.list,
      ),
      'Slots added to ${area.name}',
    );
  }

  Future<void> _slotActions(LayoutSlot slot) async {
    if (slot.status == 'OCCUPIED') {
      _snack('Slot ${slot.slotNumber} has a car in it${slot.occupantPlateNo != null ? ' (${slot.occupantPlateNo})' : ''} '
          '- it frees up when the car is sent out.');
      return;
    }
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('Slot ${slot.slotNumber}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ),
            if (slot.status != 'FREE')
              ListTile(
                leading: Icon(Icons.check_circle_outline, color: Colors.green.shade700),
                title: const Text('Available for valet'),
                onTap: () => Navigator.of(ctx).pop('FREE'),
              ),
            if (slot.status != 'RESERVED')
              ListTile(
                leading: Icon(Icons.bookmark_outline, color: Colors.blue.shade700),
                title: const Text('Reserve (keep empty for now)'),
                onTap: () => Navigator.of(ctx).pop('RESERVED'),
              ),
            if (slot.status != 'OUT_OF_SERVICE')
              ListTile(
                leading: Icon(Icons.block, color: Colors.grey.shade700),
                title: const Text('Switch off (blocked / not usable)'),
                onTap: () => Navigator.of(ctx).pop('OUT_OF_SERVICE'),
              ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: Colors.red.shade700),
              title: Text('Remove slot', style: TextStyle(color: Colors.red.shade700)),
              onTap: () => Navigator.of(ctx).pop('DELETE'),
            ),
          ],
        ),
      ),
    );
    if (action == null) return;
    if (action == 'DELETE') {
      if (!mounted) return;
      final ok = await showConfirmDialog(
        context,
        title: 'Remove slot ${slot.slotNumber}?',
        message: 'Drivers will no longer be offered this slot.',
        confirmLabel: 'Remove',
        destructive: true,
      );
      if (!ok) return;
      await _run(() => _service.deleteSlot(slot.id), 'Slot ${slot.slotNumber} removed');
    } else {
      await _run(() => _service.setSlotStatus(slotId: slot.id, status: action), 'Slot ${slot.slotNumber} updated');
    }
  }

  // ---- build ----

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Parking Setup'),
        automaticallyImplyLeading: !widget.isHome,
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh), tooltip: 'Refresh'),
          if (widget.isHome) IconButton(onPressed: _logout, icon: const Icon(Icons.logout), tooltip: 'Log out'),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null && _layout == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: const Text('Try again')),
          ]),
        ),
      );
    }
    final layout = _layout!;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _summary(layout),
          const SizedBox(height: 16),
          if (layout.floors.isEmpty)
            _note('No floors yet. Ask the admin to add the building and floors given to the valet '
                '(Web portal > Parking Management > Valet Layout); you can then add areas and slots here.'),
          for (final floor in layout.floors) ...[
            _floorCard(floor),
            const SizedBox(height: 12),
          ],
          if (layout.areasWithoutFloor.isNotEmpty) ...[
            Text('Areas not on a floor',
                style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey.shade700)),
            const SizedBox(height: 8),
            for (final area in layout.areasWithoutFloor) _areaBlock(area),
          ],
          const SizedBox(height: 8),
          _legend(),
        ],
      ),
    );
  }

  Widget _summary(ParkingLayout l) {
    Widget stat(String label, int value, Color color) => Expanded(
          child: Column(children: [
            Text('$value',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color,
                    fontFeatures: const [FontFeature.tabularFigures()])),
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          ]),
        );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(children: [
        stat('Slots', l.totalSlots, Colors.grey.shade900),
        stat('Free', l.freeSlots, Colors.green.shade700),
        stat('Occupied', l.occupiedSlots, Colors.orange.shade800),
        stat('Off', l.outOfServiceSlots, Colors.grey.shade600),
      ]),
    );
  }

  Widget _note(String text) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.shade100),
        ),
        child: Text(text, style: TextStyle(color: Colors.blue.shade900, fontSize: 13)),
      );

  Widget _floorCard(LayoutFloor floor) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: const Icon(Icons.layers_outlined),
        title: Text(floor.title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('${floor.freeSlots} free of ${floor.totalSlots} · ${floor.areas.length} area${floor.areas.length == 1 ? '' : 's'}'),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          for (final area in floor.areas) _areaBlock(area),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _addArea(floor),
              icon: const Icon(Icons.add),
              label: const Text('Add valet area on this floor'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _areaBlock(LayoutArea area) {
    final selfPark = area.purpose == 'SELF_PARK';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(area.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
              if (selfPark)
                const Chip(label: Text('Self-park'), visualDensity: VisualDensity.compact)
              else
                Text('${area.freeSlots}/${area.totalSlots} free',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
            ],
          ),
          const SizedBox(height: 8),
          if (area.slots.isEmpty)
            Text('No slots yet.', style: TextStyle(fontSize: 13, color: Colors.grey.shade600))
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final s in area.slots) _slotChip(s)],
            ),
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: () => _addSlots(area),
            icon: const Icon(Icons.add_box_outlined, size: 18),
            label: const Text('Add slots'),
          ),
        ],
      ),
    );
  }

  static const Map<String, MaterialColor> _statusColors = {
    'FREE': Colors.green,
    'OCCUPIED': Colors.orange,
    'RESERVED': Colors.blue,
    'OUT_OF_SERVICE': Colors.grey,
  };

  Widget _slotChip(LayoutSlot s) {
    final color = _statusColors[s.status] ?? Colors.grey;
    final off = s.status == 'OUT_OF_SERVICE';
    return Material(
      color: color.shade50,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _slotActions(s),
        child: Container(
          constraints: const BoxConstraints(minWidth: 52),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.shade300),
          ),
          child: Text(
            s.slotNumber,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: color.shade900,
              decoration: off ? TextDecoration.lineThrough : null,
            ),
          ),
        ),
      ),
    );
  }

  Widget _legend() {
    Widget item(String label, MaterialColor c) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: c.shade300, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
        ]);
    return Wrap(spacing: 14, runSpacing: 6, children: [
      item('Free', Colors.green),
      item('Car parked', Colors.orange),
      item('Reserved', Colors.blue),
      item('Switched off', Colors.grey),
    ]);
  }
}

class _SlotBatch {
  final String? prefix;
  final int? start;
  final int? count;
  final List<String>? list;
  _SlotBatch.range(this.prefix, this.start, this.count) : list = null;
  _SlotBatch.list(this.list)
      : prefix = null,
        start = null,
        count = null;
}

class _AddSlotsDialog extends StatefulWidget {
  final LayoutArea area;
  const _AddSlotsDialog({required this.area});

  @override
  State<_AddSlotsDialog> createState() => _AddSlotsDialogState();
}

class _AddSlotsDialogState extends State<_AddSlotsDialog> {
  bool _range = true;
  final _prefix = TextEditingController();
  final _start = TextEditingController(text: '1');
  final _count = TextEditingController(text: '10');
  final _list = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _prefix.dispose();
    _start.dispose();
    _count.dispose();
    _list.dispose();
    super.dispose();
  }

  String get _preview {
    final start = int.tryParse(_start.text) ?? 1;
    final count = int.tryParse(_count.text) ?? 0;
    if (count < 1) return '';
    final first = '${_prefix.text}$start';
    final last = '${_prefix.text}${start + count - 1}';
    return count == 1 ? 'Adds $first' : 'Adds $first … $last ($count slots)';
  }

  void _submit() {
    if (_range) {
      final start = int.tryParse(_start.text);
      final count = int.tryParse(_count.text);
      if (start == null || start < 0 || count == null || count < 1 || count > 500) {
        setState(() => _error = 'Enter a start number and a count between 1 and 500.');
        return;
      }
      Navigator.of(context).pop(_SlotBatch.range(_prefix.text.trim(), start, count));
    } else {
      final numbers = _list.text.split(RegExp(r'[,\n]')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      if (numbers.isEmpty) {
        setState(() => _error = 'Type at least one slot number.');
        return;
      }
      Navigator.of(context).pop(_SlotBatch.list(numbers));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add slots to ${widget.area.name}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Numbered range')),
                ButtonSegment(value: false, label: Text('List')),
              ],
              selected: {_range},
              onSelectionChanged: (v) => setState(() => _range = v.first),
            ),
            const SizedBox(height: 14),
            if (_range) ...[
              TextField(
                controller: _prefix,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'Prefix (optional)', hintText: 'e.g. B1-', border: OutlineInputBorder(), isDense: true),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _start,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Start at', border: OutlineInputBorder(), isDense: true),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _count,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'How many', border: OutlineInputBorder(), isDense: true),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              Text(_preview, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
            ] else
              TextField(
                controller: _list,
                minLines: 3,
                maxLines: 6,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Slot numbers',
                  hintText: 'A1, A2, A5, VIP-1\n(comma or one per line)',
                  border: OutlineInputBorder(),
                ),
              ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
            ],
            const SizedBox(height: 8),
            Text('Drivers are offered slots in this order - lowest number first.',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(onPressed: _submit, child: const Text('Add slots')),
      ],
    );
  }
}
