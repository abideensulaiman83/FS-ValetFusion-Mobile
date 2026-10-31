// lib/components/condition_photos.dart
//
// Condition photos of a car. ConditionPhotosCard is the driver's check-in step (front, back,
// left, right - tap a slot to photograph it); ConditionPhotosStrip is the read-only row the lobby
// looks at when handing the car back, so any new damage can be checked against how it came in.
// Photos are resized on the phone (1600 px, ~70% JPEG) before upload - a few hundred KB each.
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../l10n/app_strings.dart';
import '../services/offline_queue.dart';
import '../services/plan_service.dart';
import '../services/valet_service.dart';
import '../theme/app_theme.dart';
import 'premium.dart';

const List<String> _angles = ['FRONT', 'BACK', 'LEFT', 'RIGHT'];
/// 'Front' / 'Back' / 'Left' / 'Right' in the active language.
String _angleLabel(BuildContext context, String a) => a.isEmpty ? a : tr(context, a[0] + a.substring(1).toLowerCase());

/// Photo bytes loaded once per url and kept for the session - the strip and the full-screen view
/// share them, and the endpoint needs the auth header anyway.
final Map<String, Future<Uint8List>> _cache = {};
Future<Uint8List> _bytes(String url) =>
    _cache.putIfAbsent(url, () => ValetService().fetchPhotoBytes(url).then(Uint8List.fromList));

class _PhotoThumb extends StatelessWidget {
  final String url;
  final double size;
  const _PhotoThumb({required this.url, this.size = 72});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _bytes(url),
      builder: (context, snap) {
        if (snap.hasData) return Image.memory(snap.data!, width: size, height: size, fit: BoxFit.cover);
        return Container(
          width: size,
          height: size,
          color: context.vf.line,
          alignment: Alignment.center,
          child: snap.hasError
              ? Icon(Icons.broken_image_outlined, color: context.vf.textSecondary)
              : const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
        );
      },
    );
  }
}

void _openFull(BuildContext context, VehiclePhotoInfo photo) {
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, title: Text(_angleLabel(context, photo.angle))),
      body: Center(
        child: InteractiveViewer(
          maxScale: 5,
          child: FutureBuilder<Uint8List>(
            future: _bytes(photo.url),
            builder: (context, snap) => snap.hasData
                ? Image.memory(snap.data!, fit: BoxFit.contain)
                : const CircularProgressIndicator(color: Colors.white),
          ),
        ),
      ),
    ),
  ));
}

/// Driver's check-in step: photograph each side. Existing photos load on open.
class ConditionPhotosCard extends StatefulWidget {
  final int parkingVehicleId;
  const ConditionPhotosCard({super.key, required this.parkingVehicleId});

  @override
  State<ConditionPhotosCard> createState() => ConditionPhotosCardState();
}

class ConditionPhotosCardState extends State<ConditionPhotosCard> {
  final _service = ValetService();
  final _picker = ImagePicker();
  List<VehiclePhotoInfo> _photos = [];
  final Set<String> _uploading = {};
  String? _error;

  int _queuedBefore = 0;

  @override
  void initState() {
    super.initState();
    reload();
    OfflineQueue.instance.pending.addListener(_onQueueChanged);
  }

  @override
  void dispose() {
    OfflineQueue.instance.pending.removeListener(_onQueueChanged);
    super.dispose();
  }

  // A queued photo just went up - fetch the server copy so the slot shows it.
  void _onQueueChanged() {
    final now = OfflineQueue.instance.pendingPhotosFor(widget.parkingVehicleId).length;
    if (now < _queuedBefore) reload();
    _queuedBefore = now;
    if (mounted) setState(() {});
  }

  Future<void> reload() async {
    try {
      final photos = await _service.fetchPhotos(widget.parkingVehicleId);
      if (mounted) setState(() => _photos = photos);
    } catch (_) {}
  }

  /// Also used by the receive flow to attach the plate-recognition photo as FRONT.
  Future<void> upload(String filePath, String angle) async {
    setState(() {
      _uploading.add(angle);
      _error = null;
    });
    try {
      await _service.uploadPhoto(widget.parkingVehicleId, filePath, angle);
      await reload();
    } catch (e) {
      if (isNetworkError(e)) {
        await OfflineQueue.instance.queuePhoto(parkingVehicleId: widget.parkingVehicleId, filePath: filePath, angle: angle);
        _queuedBefore = OfflineQueue.instance.pendingPhotosFor(widget.parkingVehicleId).length;
      } else if (mounted && e is! PlanRequiredException) {
        // (PLAN_REQUIRED already opened the Premium sheet.)
        setState(() => _error = e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _uploading.remove(angle));
    }
  }

  Future<void> _take(String angle) async {
    // Condition photos are Premium (DAMAGE_MARKING) - say so before opening the camera.
    if (!PlanController.instance.has(PremiumFeature.damageMarking)) {
      showPremiumSheet(context, featureKey: PremiumFeature.damageMarking);
      return;
    }
    final picked = await _picker.pickImage(source: ImageSource.camera, maxWidth: 1600, maxHeight: 1600, imageQuality: 70);
    if (picked == null) return;
    await upload(picked.path, angle);
  }

  @override
  Widget build(BuildContext context) {
    final done = _angles.where((a) => _photos.any((p) => p.angle == a)).length;
    final vf = context.vf;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: vf.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: vf.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(tr(context, 'Condition photos'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: vf.textPrimary)),
              const SizedBox(width: 6),
              const PremiumStar(featureKey: PremiumFeature.damageMarking),
              const Spacer(),
              Text(tr(context, '{done} of {total}', {'done': done, 'total': 4}), style: TextStyle(fontSize: 12, color: done == 4 ? vf.success : vf.textSecondary)),
            ],
          ),
          const SizedBox(height: 4),
          Text(tr(context, 'Photograph each side now - shown again at handover if the guest asks about damage.'),
              style: TextStyle(fontSize: 12, color: vf.textSecondary)),
          const SizedBox(height: 12),
          Row(
            children: _angles.map((angle) {
              final photo = _photos.where((p) => p.angle == angle).lastOrNull;
              final queued = photo == null
                  ? OfflineQueue.instance.pendingPhotosFor(widget.parkingVehicleId)
                      .where((a) => a.payload['angle'] == angle).lastOrNull
                  : null;
              final busy = _uploading.contains(angle);
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: busy ? null : () => photo != null ? _openFull(context, photo) : _take(angle),
                    onLongPress: busy ? null : () => _take(angle),
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: busy
                                ? Container(color: vf.card2, alignment: Alignment.center,
                                    child: const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                                : photo != null
                                    ? LayoutBuilder(builder: (_, c) => _PhotoThumb(url: photo.url, size: c.maxWidth))
                                    : queued != null
                                        // Taken without signal - shown from the phone until it uploads.
                                        ? Stack(fit: StackFit.expand, children: [
                                            Image.file(File(queued.payload['filePath'] as String), fit: BoxFit.cover),
                                            Container(
                                              alignment: Alignment.bottomCenter,
                                              color: Colors.black26,
                                              child: const Padding(
                                                padding: EdgeInsets.all(3),
                                                child: Icon(Icons.cloud_upload_outlined, size: 18, color: Colors.white),
                                              ),
                                            ),
                                          ])
                                        : Container(
                                        decoration: BoxDecoration(
                                          color: vf.card2,
                                          border: Border.all(color: vf.line),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        alignment: Alignment.center,
                                        child: Icon(Icons.add_a_photo_outlined, color: vf.textSecondary),
                                      ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(_angleLabel(context, angle), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: vf.textBody)),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          if (_photos.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(tr(context, 'Tap a photo to view it, long-press to retake.'), style: TextStyle(fontSize: 11, color: vf.textSecondary)),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(fontSize: 12, color: vf.danger)),
          ],
        ],
      ),
    );
  }
}

/// Read-only 2-column grid of the check-in photos - the driver's "Find my car" card, big enough
/// to recognise the car across a car park. Tap to view full screen.
class ConditionPhotosGrid extends StatefulWidget {
  final int parkingVehicleId;
  const ConditionPhotosGrid({super.key, required this.parkingVehicleId});

  @override
  State<ConditionPhotosGrid> createState() => _ConditionPhotosGridState();
}

class _ConditionPhotosGridState extends State<ConditionPhotosGrid> {
  late final Future<List<VehiclePhotoInfo>> _photos = ValetService().fetchPhotos(widget.parkingVehicleId);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<VehiclePhotoInfo>>(
      future: _photos,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
          );
        }
        final photos = snap.data ?? const [];
        if (photos.isEmpty) {
          return Text(tr(context, snap.hasError ? 'Photos could not be loaded.' : 'No photos were taken at check-in.'),
              style: TextStyle(fontSize: 13, color: context.vf.textSecondary));
        }
        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: photos
              .map((p) => InkWell(
                    onTap: () => _openFull(context, p),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Stack(fit: StackFit.expand, children: [
                        LayoutBuilder(builder: (_, c) => _PhotoThumb(url: p.url, size: c.maxWidth)),
                        Align(
                          alignment: AlignmentDirectional.bottomStart,
                          child: Container(
                            margin: const EdgeInsets.all(6),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.ink.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(4)),
                            child: Text(_angleLabel(context, p.angle),
                                style: const TextStyle(color: AppColors.inkText, fontSize: 11, fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ]),
                    ),
                  ))
              .toList(),
        );
      },
    );
  }
}

/// Read-only row for the lobby at handover. Renders nothing if the car has no photos.
class ConditionPhotosStrip extends StatefulWidget {
  final int parkingVehicleId;
  const ConditionPhotosStrip({super.key, required this.parkingVehicleId});

  @override
  State<ConditionPhotosStrip> createState() => _ConditionPhotosStripState();
}

class _ConditionPhotosStripState extends State<ConditionPhotosStrip> {
  late final Future<List<VehiclePhotoInfo>> _photos = ValetService().fetchPhotos(widget.parkingVehicleId);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<VehiclePhotoInfo>>(
      future: _photos,
      builder: (context, snap) {
        final photos = snap.data ?? const [];
        if (photos.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            Text(tr(context, 'Condition at check-in'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.vf.textSecondary)),
            const SizedBox(height: 6),
            SizedBox(
              height: 64,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: photos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (context, i) => InkWell(
                  onTap: () => _openFull(context, photos[i]),
                  child: ClipRRect(borderRadius: BorderRadius.circular(6), child: _PhotoThumb(url: photos[i].url, size: 64)),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Public access to the cached, authenticated thumbnail (used by the check-in / check-out compare).
class ConditionPhotoThumb extends StatelessWidget {
  final String url;
  final double size;
  const ConditionPhotoThumb({super.key, required this.url, this.size = 72});

  @override
  Widget build(BuildContext context) => _PhotoThumb(url: url, size: size);
}

/// Full-screen, zoomable view of one condition photo.
void openConditionPhoto(BuildContext context, VehiclePhotoInfo photo) => _openFull(context, photo);
