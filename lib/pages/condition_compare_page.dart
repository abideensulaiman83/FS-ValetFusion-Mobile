// lib/pages/condition_compare_page.dart
//
// Check-in / check-out compare, opened from the desk's Confirm Delivery step: for each side of the
// car, the photo taken at check-in next to one taken now, plus the damage marks from check-in - so
// the desk can show the guest the car leaves as it came. "Now" photos go up through the same
// condition-photo endpoint (POST /v1/parking-vehicles/{id}/photos, same angles); a photo counts
// as a check-out photo when it was taken after the car was requested / dispatched. Premium
// (DAMAGE_MARKING), like the check-in photos.
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../components/condition_photos.dart';
import '../components/damage/damage_marking_card.dart';
import '../components/premium.dart';
import '../services/plan_service.dart';
import '../services/valet_service.dart';
import '../theme/app_theme.dart';

const List<String> _sides = ['FRONT', 'BACK', 'LEFT', 'RIGHT'];
String _sideLabel(String a) => a[0] + a.substring(1).toLowerCase();

/// Small button for the delivery dialog: "Compare condition".
class ConditionCompareButton extends StatelessWidget {
  final TicketStatusResponse data;
  const ConditionCompareButton({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.parkingVehicleId == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: OutlinedButton.icon(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ConditionComparePage(data: data))),
        icon: const Icon(Icons.compare_rounded, size: 18),
        label: Row(mainAxisSize: MainAxisSize.min, children: const [
          Text('Compare condition'),
          SizedBox(width: 6),
          PremiumStar(featureKey: PremiumFeature.damageMarking, size: 14),
        ]),
      ),
    );
  }
}

class ConditionComparePage extends StatefulWidget {
  final TicketStatusResponse data;
  const ConditionComparePage({super.key, required this.data});

  @override
  State<ConditionComparePage> createState() => _ConditionComparePageState();
}

class _ConditionComparePageState extends State<ConditionComparePage> {
  final _service = ValetService();
  final _picker = ImagePicker();
  List<VehiclePhotoInfo> _photos = const [];
  bool _loading = true;
  String? _error;
  final Set<String> _uploading = {};
  // Photos taken on this screen - always "now", whatever the clock says.
  final Map<String, VehiclePhotoInfo> _takenHere = {};

  int get _vehicleId => widget.data.parkingVehicleId!;

  /// When the car left the bay: anything photographed after this is a check-out photo.
  DateTime? get _cutoff {
    for (final s in [widget.data.requestedTime, widget.data.dispatchedTime, widget.data.arrivedTime]) {
      final t = s == null ? null : DateTime.tryParse(s);
      if (t != null) return t;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final photos = await _service.fetchPhotos(_vehicleId);
      if (mounted) setState(() => _photos = photos);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  DateTime? _t(VehiclePhotoInfo p) => DateTime.tryParse(p.takenAt);

  (VehiclePhotoInfo?, VehiclePhotoInfo?) _pair(String side) {
    final list = _photos.where((p) => p.angle == side).toList()
      ..sort((a, b) => (_t(a) ?? DateTime(0)).compareTo(_t(b) ?? DateTime(0)));
    final here = _takenHere[side];
    final cutoff = _cutoff;
    VehiclePhotoInfo? before, after;
    if (cutoff != null) {
      for (final p in list) {
        final t = _t(p);
        if (here != null && p.id == here.id) continue;
        if (t != null && t.isAfter(cutoff)) {
          after = p;
        } else {
          before = p; // the latest retake before the car left
        }
      }
    } else {
      final rest = list.where((p) => here == null || p.id != here.id).toList();
      if (rest.isNotEmpty) before = rest.first;
      if (rest.length > 1) after = rest.last;
    }
    return (before, here ?? after);
  }

  Future<void> _takeNow(String side) async {
    if (!PlanController.instance.has(PremiumFeature.damageMarking)) {
      showPremiumSheet(context, featureKey: PremiumFeature.damageMarking);
      return;
    }
    final picked = await _picker.pickImage(source: ImageSource.camera, maxWidth: 1600, maxHeight: 1600, imageQuality: 70);
    if (picked == null) return;
    setState(() => _uploading.add(side));
    try {
      final photo = await _service.uploadPhoto(_vehicleId, picked.path, side);
      if (!mounted) return;
      setState(() {
        _takenHere[side] = photo;
        _photos = [..._photos, photo];
      });
    } catch (e) {
      if (mounted && e is! PlanRequiredException) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger));
      }
    } finally {
      if (mounted) setState(() => _uploading.remove(side));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = widget.data;
    final vehicle = [d.vehicleColor, d.vehicleMake, d.vehicleModel].where((s) => s != null && s.isNotEmpty).join(' ');
    final others = _photos.where((p) => !_sides.contains(p.angle)).toList();
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          const Text('Compare condition'),
          Text('Ticket ${d.ticketNo}${d.plateNo != null ? ' · ${d.plateNo}' : ''}',
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 11.5)),
        ]),
        actions: [IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded))],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (vehicle.isNotEmpty) Text(vehicle, style: theme.textTheme.titleMedium),
            Text(
              'Left: at check-in${d.parkingInTime != null ? ' (${_fmt(d.parkingInTime!)})' : ''}. '
              'Right: now - tap an empty slot to photograph that side.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: Text('CHECK-IN', style: theme.textTheme.labelSmall, textAlign: TextAlign.center)),
              const SizedBox(width: 10),
              Expanded(child: Text('NOW', style: theme.textTheme.labelSmall, textAlign: TextAlign.center)),
            ]),
            const SizedBox(height: 6),
            if (_loading)
              const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_error!, style: TextStyle(color: AppColors.danger)),
              )
            else
              for (final side in _sides) _sideRow(side, theme),
            if (others.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Other photos', style: theme.textTheme.titleSmall),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final p in others)
                  InkWell(
                    onTap: () => openConditionPhoto(context, p),
                    child: ClipRRect(borderRadius: BorderRadius.circular(6), child: ConditionPhotoThumb(url: p.url, size: 72)),
                  ),
              ]),
            ],
            const SizedBox(height: 20),
            Row(children: [
              Text('Damage marked at check-in', style: theme.textTheme.titleMedium),
              const SizedBox(width: 6),
              const PremiumStar(featureKey: PremiumFeature.damageMarking),
            ]),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.line),
              ),
              child: DamageMarksView(parkingVehicleId: _vehicleId),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  String _fmt(String iso) {
    final t = DateTime.tryParse(iso);
    return t == null ? iso : DateFormat('d MMM, HH:mm').format(t);
  }

  Widget _sideRow(String side, ThemeData theme) {
    final (before, now) = _pair(side);
    final busy = _uploading.contains(side);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_sideLabel(side), style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: _tile(before, emptyText: 'No check-in photo')),
            const SizedBox(width: 10),
            Expanded(
              child: busy
                  ? _frame(const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))))
                  : now != null
                      ? _tile(now, onLongPress: () => _takeNow(side))
                      : InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => _takeNow(side),
                          child: _frame(Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.add_a_photo_outlined, color: AppColors.textSecondary),
                            const SizedBox(height: 4),
                            Text('Take now', style: theme.textTheme.bodySmall),
                          ])),
                        ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _frame(Widget child) => AspectRatio(
        aspectRatio: 4 / 3,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.card2,
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(8),
          ),
          child: child,
        ),
      );

  Widget _tile(VehiclePhotoInfo? photo, {String emptyText = '', VoidCallback? onLongPress}) {
    if (photo == null) {
      return _frame(Center(child: Text(emptyText, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall)));
    }
    final t = _t(photo);
    return InkWell(
      onTap: () => openConditionPhoto(context, photo),
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(8),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(fit: StackFit.expand, children: [
            LayoutBuilder(builder: (_, c) => ConditionPhotoThumb(url: photo.url, size: c.maxWidth)),
            if (t != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  color: AppColors.ink.withValues(alpha: 0.55),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Text(DateFormat('d MMM HH:mm').format(t), style: AppTheme.mono(size: 10.5, color: AppColors.inkText)),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
