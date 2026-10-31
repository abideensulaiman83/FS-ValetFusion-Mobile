// lib/components/damage/damage_marking_card.dart
//
// Damage marking (plan D10). DamageMarkingCard is the driver's check-in step: tap the car to drop
// a numbered mark, pick scratch / dent / crack / other, add a note, then save - the marks already
// on the ticket (from the app or the portal) load first and stay read-only. DamageMarksView is the
// read-only diagram + list shown at handover. Premium (DAMAGE_MARKING): on a Free plan the card
// shows the star and the "Part of Premium" sheet instead of the editor; a PLAN_REQUIRED from the
// server does the same.
import 'package:flutter/material.dart';
import '../../services/damage_service.dart';
import '../../services/plan_service.dart';
import '../../theme/app_theme.dart';
import '../premium.dart';
import 'car_diagram.dart';

class DamageMarkingCard extends StatefulWidget {
  final int parkingVehicleId;
  const DamageMarkingCard({super.key, required this.parkingVehicleId});

  @override
  State<DamageMarkingCard> createState() => _DamageMarkingCardState();
}

class _DamageMarkingCardState extends State<DamageMarkingCard> {
  final _service = DamageService();
  List<DamageMark> _saved = const [];
  final List<DamageMark> _pending = [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant DamageMarkingCard old) {
    super.didUpdateWidget(old);
    if (old.parkingVehicleId != widget.parkingVehicleId) {
      _pending.clear();
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final marks = await _service.load(widget.parkingVehicleId);
      if (mounted) setState(() => _saved = marks);
    } catch (e) {
      if (mounted && e is! PlanRequiredException) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<DamageMark> get _all => [..._saved, ..._pending];

  Future<void> _addAt(double x, double y, String? part) async {
    if (!PlanController.instance.has(PremiumFeature.damageMarking)) {
      showPremiumSheet(context, featureKey: PremiumFeature.damageMarking);
      return;
    }
    if (_all.length >= 50) {
      setState(() => _error = 'Up to 50 marks per car.');
      return;
    }
    final mark = await showDamageMarkSheet(context, number: _all.length + 1, part: part);
    if (mark == null || !mounted) return;
    setState(() => _pending.add(DamageMark(type: mark.type, note: mark.note, xPct: x, yPct: y)));
  }

  Future<void> _onMarkTap(int index) async {
    final all = _all;
    final m = all[index];
    if (m.saved) {
      _showSavedMark(index + 1, m);
      return;
    }
    final pendingIndex = index - _saved.length;
    final edited = await showDamageMarkSheet(context, number: index + 1, initial: m, allowRemove: true);
    if (!mounted || edited == null) return;
    setState(() {
      if (edited.note == _removeSentinel) {
        _pending.removeAt(pendingIndex);
      } else {
        _pending[pendingIndex] = m.copyWith(type: edited.type, note: edited.note);
      }
    });
  }

  void _showSavedMark(int number, DamageMark m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('#$number ${m.type.label}${m.note.isEmpty ? '' : ' - ${m.note}'} (already saved)'),
    ));
  }

  Future<void> _save() async {
    if (_pending.isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final r = await _service.save(widget.parkingVehicleId, List.of(_pending));
      if (!mounted) return;
      _pending.clear();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(r.failed == 0 ? 'Damage marks saved' : '${r.saved} saved, ${r.failed} could not be saved'),
        backgroundColor: r.failed == 0 ? AppColors.success : AppColors.warning,
      ));
      await _load();
    } catch (e) {
      // PLAN_REQUIRED already opened the Premium sheet.
      if (mounted && e is! PlanRequiredException) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ValueListenableBuilder<PlanInfo?>(
      valueListenable: PlanController.instance.plan,
      builder: (context, plan, _) {
        final locked = !(plan?.has(PremiumFeature.damageMarking) ?? true);
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Text('Damage marking', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(width: 6),
                const PremiumStar(featureKey: PremiumFeature.damageMarking),
                const Spacer(),
                if (_all.isNotEmpty)
                  Text('${_all.length} mark${_all.length == 1 ? '' : 's'}', style: theme.textTheme.bodySmall),
              ]),
              const SizedBox(height: 4),
              Text(
                locked
                    ? 'Mark existing scratches and dents on the car - part of Premium.'
                    : 'Tap the car where there is existing damage. Front of the car is at the top.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 260),
                  child: _loading
                      ? const AspectRatio(
                          aspectRatio: kDiagramW / kDiagramH,
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : CarDiagram(
                          marks: _all,
                          dimmed: locked,
                          onTap: _saving ? null : _addAt,
                          onMarkTap: _onMarkTap,
                        ),
                ),
              ),
              const SizedBox(height: 10),
              const DamageTypeLegend(),
              if (_all.isNotEmpty) ...[
                const SizedBox(height: 10),
                DamageMarkList(marks: _all, onTap: _onMarkTap),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(fontSize: 12, color: AppColors.danger)),
              ],
              const SizedBox(height: 12),
              if (locked)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => showPremiumSheet(context, featureKey: PremiumFeature.damageMarking),
                    icon: const Icon(Icons.star_rounded, size: 18, color: AppColors.brass),
                    label: const Text('Part of Premium'),
                  ),
                )
              else if (_pending.isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.save_outlined, size: 18),
                    label: Text(_saving ? 'Saving...' : 'Save ${_pending.length} mark${_pending.length == 1 ? '' : 's'}'),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Read-only diagram and list of the marks on a ticket - for handover and the compare view.
class DamageMarksView extends StatefulWidget {
  final int parkingVehicleId;
  final double maxDiagramWidth;
  const DamageMarksView({super.key, required this.parkingVehicleId, this.maxDiagramWidth = 240});

  @override
  State<DamageMarksView> createState() => _DamageMarksViewState();
}

class _DamageMarksViewState extends State<DamageMarksView> {
  late Future<List<DamageMark>> _marks = DamageService().load(widget.parkingVehicleId);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<List<DamageMark>>(
      future: _marks,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
        }
        if (snap.hasError) {
          return Row(children: [
            Expanded(child: Text('Damage marks could not be loaded.', style: theme.textTheme.bodySmall)),
            TextButton(
              onPressed: () => setState(() => _marks = DamageService().load(widget.parkingVehicleId)),
              child: const Text('Retry'),
            ),
          ]);
        }
        final marks = snap.data ?? const [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: widget.maxDiagramWidth),
                child: CarDiagram(marks: marks),
              ),
            ),
            const SizedBox(height: 8),
            if (marks.isEmpty)
              Text('No damage was marked at check-in.', style: theme.textTheme.bodyMedium)
            else
              DamageMarkList(marks: marks),
          ],
        );
      },
    );
  }
}

class DamageTypeLegend extends StatelessWidget {
  const DamageTypeLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      alignment: WrapAlignment.center,
      children: [
        for (final t in DamageType.values)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: damageTypeColor(t, b), shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Text(t.label, style: Theme.of(context).textTheme.bodySmall),
          ]),
      ],
    );
  }
}

class DamageMarkList extends StatelessWidget {
  final List<DamageMark> marks;
  final void Function(int index)? onTap;
  const DamageMarkList({super.key, required this.marks, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        for (var i = 0; i < marks.length; i++)
          InkWell(
            onTap: onTap == null ? null : () => onTap!(i),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DamageMarkDot(number: i + 1, mark: marks[i], size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(text: marks[i].type.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                        if (marks[i].note.isNotEmpty) TextSpan(text: ' - ${marks[i].note}'),
                        if (!marks[i].saved)
                          TextSpan(text: '  not saved yet', style: TextStyle(color: AppColors.warning, fontSize: 11.5)),
                      ]),
                      style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textBody),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

const String _removeSentinel = '\u0000remove';

/// Type + note for one mark. Returns null on cancel; a mark whose note is the remove sentinel
/// when "Remove" was tapped.
Future<DamageMark?> showDamageMarkSheet(BuildContext context,
    {required int number, String? part, DamageMark? initial, bool allowRemove = false}) {
  var type = initial?.type ?? DamageType.scratch;
  final note = TextEditingController(text: initial?.note ?? (part ?? ''));
  return showModalBottomSheet<DamageMark>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(sheetContext).viewInsets.bottom),
      child: StatefulBuilder(builder: (context, setSheet) {
        final theme = Theme.of(context);
        DamageMark result([String? overrideNote]) =>
            DamageMark(type: type, note: overrideNote ?? note.text.trim(), xPct: 0, yPct: 0);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Mark #$number${part != null && initial == null ? ' - $part' : ''}', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in DamageType.values)
                  ChoiceChip(
                    label: Text(t.label),
                    selected: type == t,
                    avatar: CircleAvatar(backgroundColor: damageTypeColor(t, theme.brightness), radius: 6),
                    onSelected: (_) => setSheet(() => type = t),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: note,
              maxLength: 200,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Note', hintText: 'e.g. Bonnet, 5 cm scratch near the badge'),
            ),
            const SizedBox(height: 8),
            Row(children: [
              if (allowRemove)
                TextButton.icon(
                  onPressed: () => Navigator.of(sheetContext).pop(result(_removeSentinel)),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Remove'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                ),
              const Spacer(),
              TextButton(onPressed: () => Navigator.of(sheetContext).pop(), child: const Text('Cancel')),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => Navigator.of(sheetContext).pop(result()),
                child: Text(initial == null ? 'Add mark' : 'Update'),
              ),
            ]),
          ],
        );
      }),
    ),
  ); // the controller lives until the sheet has animated out; left to GC
}
