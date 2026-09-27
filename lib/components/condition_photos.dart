// lib/components/condition_photos.dart
//
// Condition photos of a car. ConditionPhotosCard is the driver's check-in step (front, back,
// left, right - tap a slot to photograph it); ConditionPhotosStrip is the read-only row the lobby
// looks at when handing the car back, so any new damage can be checked against how it came in.
// Photos are resized on the phone (1600 px, ~70% JPEG) before upload - a few hundred KB each.
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/valet_service.dart';

const List<String> _angles = ['FRONT', 'BACK', 'LEFT', 'RIGHT'];
String _angleLabel(String a) => a[0] + a.substring(1).toLowerCase();

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
          color: Colors.grey.shade200,
          alignment: Alignment.center,
          child: snap.hasError
              ? Icon(Icons.broken_image_outlined, color: Colors.grey.shade500)
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
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, title: Text(_angleLabel(photo.angle))),
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

  @override
  void initState() {
    super.initState();
    reload();
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
      if (mounted) setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _uploading.remove(angle));
    }
  }

  Future<void> _take(String angle) async {
    final picked = await _picker.pickImage(source: ImageSource.camera, maxWidth: 1600, maxHeight: 1600, imageQuality: 70);
    if (picked == null) return;
    await upload(picked.path, angle);
  }

  @override
  Widget build(BuildContext context) {
    final done = _angles.where((a) => _photos.any((p) => p.angle == a)).length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Condition photos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
              Text('$done of 4', style: TextStyle(fontSize: 12, color: done == 4 ? Colors.green.shade700 : Colors.grey.shade600)),
            ],
          ),
          const SizedBox(height: 4),
          Text('Photograph each side now - shown again at handover if the guest asks about damage.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 12),
          Row(
            children: _angles.map((angle) {
              final photo = _photos.where((p) => p.angle == angle).lastOrNull;
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
                                ? Container(color: Colors.grey.shade100, alignment: Alignment.center,
                                    child: const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                                : photo != null
                                    ? LayoutBuilder(builder: (_, c) => _PhotoThumb(url: photo.url, size: c.maxWidth))
                                    : Container(
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade50,
                                          border: Border.all(color: Colors.grey.shade300),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        alignment: Alignment.center,
                                        child: Icon(Icons.add_a_photo_outlined, color: Colors.grey.shade500),
                                      ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(_angleLabel(angle), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          if (_photos.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Tap a photo to view it, long-press to retake.', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(fontSize: 12, color: Colors.red.shade700)),
          ],
        ],
      ),
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
            Text('Condition at check-in', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey.shade700)),
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
