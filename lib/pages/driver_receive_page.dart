// lib/pages/driver_receive_page.dart
//
// The Driver's full flow - one person, one continuous handoff, matching how the valet stand
// actually works: the Driver takes the car from the guest (scan the ticket while it's still
// FREE), walks it to the gate where OCR reads the plate/color/make and links it to the ticket,
// parks it and records the bay, then hands the physical key to the Key Controller. Previously
// this was split across a separate "Gate Scanner" role, but that meant two people/logins for
// what is really one driver's single trip with the car - merged back into one flow per updated
// requirements.
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../components/barcode_scanner_page.dart';
import '../components/wash_requests_section.dart';
import '../services/ocr_service.dart';
import '../services/valet_service.dart';

class DriverReceiveFlow extends StatefulWidget {
  const DriverReceiveFlow({super.key});

  @override
  State<DriverReceiveFlow> createState() => _DriverReceiveFlowState();
}

// Shows any car a Key Controller has assigned to this driver, with full vehicle/ticket detail,
// and lets the driver mark it Arrived/Delivered - no need to already know the ticket number.
// While at least one delivery is ONTHEWAY, also pushes this device's GPS position periodically
// so the Customer and Lobby apps can see live movement + a rough ETA.
class MyDeliveriesSection extends StatefulWidget {
  const MyDeliveriesSection({super.key});

  @override
  State<MyDeliveriesSection> createState() => _MyDeliveriesSectionState();
}

class _MyDeliveriesSectionState extends State<MyDeliveriesSection> {
  final ValetService _valetService = ValetService();
  List<TicketStatusResponse> _deliveries = [];
  bool _loading = true;
  Timer? _refreshTimer;
  Timer? _locationTimer;
  final Set<int> _acting = {};

  @override
  void initState() {
    super.initState();
    _load();
    _refreshTimer = Timer.periodic(const Duration(seconds: 20), (_) => _load(silent: true));
    _locationTimer = Timer.periodic(const Duration(seconds: 15), (_) => _pushLocation());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _locationTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final deliveries = await _valetService.fetchMyDeliveries();
      if (mounted) setState(() => _deliveries = deliveries);
    } catch (_) {
      // Non-fatal on background refresh - keep showing the last known list.
    } finally {
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  Future<void> _pushLocation() async {
    final onTheWay = _deliveries.where((d) => d.status == 'ONTHEWAY').toList();
    if (onTheWay.isEmpty) return;
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;
      if (!await Geolocator.isLocationServiceEnabled()) return;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      for (final delivery in onTheWay) {
        if (delivery.parkingVehicleId == null) continue;
        await _valetService.updateDriverLocation(
          parkingVehicleId: delivery.parkingVehicleId!,
          lat: position.latitude,
          lng: position.longitude,
        );
      }
    } catch (_) {
      // Non-fatal - a missed GPS ping just means one stale ETA update, not worth alarming the driver.
    }
  }

  Future<void> _markArrived(TicketStatusResponse d) async {
    if (d.parkingVehicleId == null) return;
    setState(() => _acting.add(d.parkingVehicleId!));
    try {
      await _valetService.arriveVehicle(d.parkingVehicleId!);
      await _load();
    } catch (e) {
      _showSnack(e.toString().replaceAll('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _acting.remove(d.parkingVehicleId));
    }
  }

  Future<void> _markDelivered(TicketStatusResponse d) async {
    if (d.parkingVehicleId == null) return;
    setState(() => _acting.add(d.parkingVehicleId!));
    try {
      await _valetService.deliverVehicle(d.parkingVehicleId!);
      await _load();
    } catch (e) {
      _showSnack(e.toString().replaceAll('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _acting.remove(d.parkingVehicleId));
    }
  }

  void _showSnack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? Colors.red.shade700 : Colors.green.shade700,
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_deliveries.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('My Deliveries', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.grey.shade800)),
        const SizedBox(height: 10),
        for (final d in _deliveries) ...[
          _buildDeliveryCard(d),
          const SizedBox(height: 12),
        ],
        const Divider(height: 28),
      ],
    );
  }

  Widget _buildDeliveryCard(TicketStatusResponse d) {
    final isActing = d.parkingVehicleId != null && _acting.contains(d.parkingVehicleId);
    final isArrived = d.status == 'ARRIVED';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade50, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.indigo.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.directions_car_filled, color: Colors.indigo.shade400),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${d.vehicleColor ?? ''} ${d.vehicleMake ?? 'Vehicle'}'.trim(),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
              Chip(
                label: Text(isArrived ? 'Arrived' : 'On the way', style: const TextStyle(color: Colors.white, fontSize: 11)),
                backgroundColor: isArrived ? Colors.green.shade600 : Colors.orange.shade700,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              _detail('Ticket', d.ticketNo),
              _detail('Plate', d.plateNo ?? '-'),
              _detail('Bay', d.bayNo ?? '-'),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (!isArrived)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isActing ? null : () => _markArrived(d),
                    icon: const Icon(Icons.flag_outlined, size: 18),
                    label: const Text('Mark Arrived'),
                  ),
                ),
              if (!isArrived) const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isActing ? null : () => _markDelivered(d),
                  icon: isActing
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_circle_outline, size: 18),
                  label: Text(isActing ? 'Saving...' : 'Hand Over to Customer'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo.shade600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detail(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _DriverReceiveFlowState extends State<DriverReceiveFlow> {
  final ValetService _valetService = ValetService();
  final OcrService _ocrService = OcrService();
  final ImagePicker _imagePicker = ImagePicker();

  final _ticketNoController = TextEditingController();
  final _plateNoController = TextEditingController();
  final _vehicleMakeController = TextEditingController();
  final _vehicleColorController = TextEditingController();
  final _bayNoController = TextEditingController();
  final _keyHolderNoController = TextEditingController();

  bool _loading = false;
  TicketStatusResponse? _lastLookup;

  File? _vehicleImage;
  bool _ocrRunning = false;
  OcrRecognitionResult? _ocrResult;
  bool _submitting = false;

  @override
  void dispose() {
    _ticketNoController.dispose();
    _plateNoController.dispose();
    _vehicleMakeController.dispose();
    _vehicleColorController.dispose();
    _bayNoController.dispose();
    _keyHolderNoController.dispose();
    super.dispose();
  }

  void _showSnack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? Colors.red.shade700 : Colors.green.shade700,
    ));
  }

  Future<void> _scanTicketBarcode() async {
    final scanned = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerPage(title: 'Scan Ticket Barcode')),
    );
    if (scanned != null && scanned.trim().isNotEmpty) {
      _ticketNoController.text = scanned.trim();
      await _lookup();
    }
  }

  Future<void> _lookup() async {
    final ticketNo = _ticketNoController.text.trim();
    if (ticketNo.isEmpty) {
      _showSnack('Enter or scan a ticket number first', error: true);
      return;
    }
    setState(() {
      _loading = true;
      _lastLookup = null;
      _vehicleImage = null;
      _ocrResult = null;
    });
    try {
      final data = await _valetService.checkTicketStatus(ticketNo);
      setState(() => _lastLookup = data);
      _plateNoController.clear();
      _vehicleMakeController.clear();
      _vehicleColorController.clear();
      _bayNoController.clear();
      _keyHolderNoController.clear();
    } catch (e) {
      _showSnack(e.toString().replaceAll('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _captureAndRecognize() async {
    final picked = await _imagePicker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (picked == null) return;

    final file = File(picked.path);
    setState(() {
      _vehicleImage = file;
      _ocrRunning = true;
      _ocrResult = null;
    });

    try {
      final result = await _ocrService.recognize(file);
      setState(() {
        _ocrResult = result;
        _plateNoController.text = result.plate?.raw ?? result.plate?.display ?? '';
        _vehicleColorController.text = _capitalize(result.color?.name);
        _vehicleMakeController.text = [result.vehicle?.brand, result.vehicle?.model]
            .where((s) => s != null && s.isNotEmpty)
            .join(' ');
      });
      if (result.reason == 'no_vehicle_detected') {
        _showSnack('No vehicle detected in the photo - retake it, or fill in the details manually.', error: true);
      } else if (result.needsReview) {
        _showSnack('OCR read this with low confidence - please double-check the fields below.', error: true);
      } else {
        _showSnack('Plate, color and make/model filled in from the photo.');
      }
    } catch (e) {
      _showSnack(e.toString().replaceAll('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _ocrRunning = false);
    }
  }

  String _capitalize(String? s) {
    if (s == null || s.isEmpty) return '';
    return s[0].toUpperCase() + s.substring(1);
  }

  String _pct(double? v) => v == null ? '-' : '${(v * 100).round()}%';

  Future<void> _submitReceive() async {
    final ticketNo = _ticketNoController.text.trim();
    if (_plateNoController.text.trim().isEmpty) {
      _showSnack('Please enter the Plate Number (or capture a photo first)', error: true);
      return;
    }

    setState(() => _submitting = true);
    try {
      await _valetService.receiveVehicle(
        ticketNo: ticketNo,
        plateNo: _plateNoController.text.trim(),
        vehicleMake: _vehicleMakeController.text.trim().isEmpty ? null : _vehicleMakeController.text.trim(),
        vehicleColor: _vehicleColorController.text.trim().isEmpty ? null : _vehicleColorController.text.trim(),
        requestedRemarks: 'Received by driver (OCR-assisted)',
      );
      _showSnack('Vehicle linked to ticket $ticketNo - now park it and record the bay.');
      // Refresh the lookup so the flow drops into the "record parking details" step below.
      await _lookup();
    } catch (e) {
      _showSnack(e.toString().replaceAll('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _submitParkDetails() async {
    final data = _lastLookup;
    if (data == null || data.parkingVehicleId == null) return;
    if (_bayNoController.text.trim().isEmpty) {
      _showSnack('Please enter the bay number', error: true);
      return;
    }

    setState(() => _submitting = true);
    try {
      await _valetService.recordParkDetails(
        parkingVehicleId: data.parkingVehicleId!,
        bayNo: _bayNoController.text.trim(),
        keyHolderNo: _keyHolderNoController.text.trim().isEmpty ? null : _keyHolderNoController.text.trim(),
      );
      _showSnack(
        _keyHolderNoController.text.trim().isEmpty
            ? 'Parked - ticket ${data.ticketNo}, bay ${_bayNoController.text.trim()}. Hand the key to the Key Controller.'
            : 'Parked - ticket ${data.ticketNo}, bay ${_bayNoController.text.trim()}, key holder ${_keyHolderNoController.text.trim()}.',
      );
      _resetFlow();
    } catch (e) {
      _showSnack(e.toString().replaceAll('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _resetFlow() {
    _ticketNoController.clear();
    _plateNoController.clear();
    _vehicleMakeController.clear();
    _vehicleColorController.clear();
    _bayNoController.clear();
    _keyHolderNoController.clear();
    setState(() {
      _lastLookup = null;
      _vehicleImage = null;
      _ocrResult = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = _lastLookup;
    final needsReceive = data != null && data.ticketFree;
    final needsParkDetails = data != null && !data.ticketFree && data.status == 'RECEIVED' && (data.bayNo == null || data.bayNo!.trim().isEmpty);
    final alreadyParked = data != null && data.status == 'RECEIVED' && !needsParkDetails;
    final pastParking = data != null && !data.ticketFree && data.status != 'RECEIVED';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const MyDeliveriesSection(),
          const WashRequestsSection(),
          _buildScanCard(),
          if (needsReceive) ...[
            const SizedBox(height: 16),
            _buildPhotoCard(),
            if (_ocrResult != null) ...[
              const SizedBox(height: 16),
              _buildOcrDetailCard(),
            ],
            const SizedBox(height: 16),
            _buildReceiveConfirmCard(),
          ],
          if (needsParkDetails) ...[
            const SizedBox(height: 16),
            _buildParkDetailsCard(data),
          ],
          if (alreadyParked) ...[
            const SizedBox(height: 16),
            _infoCard(
              icon: Icons.check_circle,
              color: Colors.green,
              title: 'Already parked',
              message: 'Ticket ${data.ticketNo} is parked in bay ${data.bayNo}'
                  '${data.keyHolderNo != null && data.keyHolderNo!.isNotEmpty ? ' (key: ${data.keyHolderNo})' : ''}.',
            ),
          ],
          if (pastParking) ...[
            const SizedBox(height: 16),
            _infoCard(
              icon: Icons.info_outline,
              color: Colors.grey,
              title: 'Ticket status: ${data.status ?? data.ticketStatus}',
              message: 'This ticket has already moved past the parking step.',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScanCard() {
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
          const Text('Scan Ticket', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            'Scan when taking the car from the guest, and again after parking to record the bay.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ticketNoController,
            enabled: !_loading,
            decoration: const InputDecoration(
              labelText: 'Ticket Number',
              hintText: 'Scan or type the ticket number',
              prefixIcon: Icon(Icons.confirmation_number_outlined),
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _lookup(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _loading ? null : _scanTicketBarcode,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan Barcode'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _loading ? null : _lookup,
                  child: _loading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Check'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoCard() {
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
          const Text('At the Gate: Capture Vehicle Photo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            'Ticket is free - photograph the vehicle to auto-fill plate, color and make.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          if (_vehicleImage != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(_vehicleImage!, height: 180, width: double.infinity, fit: BoxFit.cover),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: _ocrRunning ? null : _captureAndRecognize,
              icon: _ocrRunning
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.camera_alt_outlined),
              label: Text(_ocrRunning
                  ? 'Reading plate...'
                  : (_vehicleImage == null ? 'Take Photo' : 'Retake Photo')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          Flexible(
            child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildOcrDetailCard() {
    final r = _ocrResult!;
    if (r.reason != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade700),
            const SizedBox(width: 10),
            Expanded(child: Text('OCR result: ${r.reason}', style: TextStyle(color: Colors.red.shade800))),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: r.needsReview ? Colors.orange.shade300 : Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('OCR Result', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const Spacer(),
              if (r.needsReview)
                Chip(
                  label: const Text('Needs review', style: TextStyle(fontSize: 11, color: Colors.white)),
                  backgroundColor: Colors.orange.shade700,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const Divider(height: 20),
          if (r.plate != null) ...[
            Text('Plate', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey.shade700, fontSize: 12)),
            _detailRow('Display', r.plate!.display ?? '-'),
            _detailRow('Raw', r.plate!.raw ?? '-'),
            _detailRow('Emirate', r.plate!.emirate != null ? '${r.plate!.emirate} (${r.plate!.emirateCode})' : '-'),
            _detailRow('Category / Number', '${r.plate!.category ?? '-'} / ${r.plate!.number ?? '-'}'),
            _detailRow('Confidence', _pct(r.plate!.confidence)),
            _detailRow('Source', r.plate!.source ?? '-'),
            _detailRow('Cross-verified', r.plate!.verified == null ? 'n/a' : (r.plate!.verified! ? 'Yes' : 'No')),
            const SizedBox(height: 10),
          ] else
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text('No plate read - enter it manually below.', style: TextStyle(fontStyle: FontStyle.italic)),
            ),
          if (r.color != null) ...[
            Text('Color', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey.shade700, fontSize: 12)),
            _detailRow('Name', _capitalize(r.color!.name)),
            _detailRow('Confidence', _pct(r.color!.confidence)),
            _detailRow('Source', r.color!.source ?? '-'),
            const SizedBox(height: 10),
          ],
          if (r.vehicle != null) ...[
            Text('Vehicle', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey.shade700, fontSize: 12)),
            _detailRow('Brand', r.vehicle!.brand ?? '-'),
            _detailRow('Brand confidence', _pct(r.vehicle!.brandConfidence)),
            _detailRow('Brand source', r.vehicle!.brandSource ?? '-'),
            _detailRow('Model', r.vehicle!.model ?? '-'),
            _detailRow('Year', r.vehicle!.year?.toString() ?? '-'),
            _detailRow('Model confidence', _pct(r.vehicle!.modelConfidence)),
            const SizedBox(height: 10),
          ],
          if (r.latencySeconds != null)
            Text('OCR processed in ${r.latencySeconds!.toStringAsFixed(2)}s',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _buildReceiveConfirmCard() {
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
          const Text('Confirm & Link to Ticket', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          TextField(
            controller: _plateNoController,
            decoration: const InputDecoration(labelText: 'Plate Number *', border: OutlineInputBorder(), isDense: true),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _vehicleMakeController,
                  decoration: const InputDecoration(labelText: 'Make / Model', border: OutlineInputBorder(), isDense: true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _vehicleColorController,
                  decoration: const InputDecoration(labelText: 'Color', border: OutlineInputBorder(), isDense: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: _submitting ? null : _submitReceive,
              icon: const Icon(Icons.link),
              label: Text(_submitting ? 'Saving...' : 'Receive Vehicle'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParkDetailsCard(TicketStatusResponse data) {
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
          const Text('Record Parking Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('Ticket ${data.ticketNo} · ${data.plateNo ?? 'plate unknown'} · ${data.vehicleColor ?? ''} ${data.vehicleMake ?? ''}'.trim(),
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          const SizedBox(height: 14),
          TextField(
            controller: _bayNoController,
            decoration: const InputDecoration(labelText: 'Bay Number *', border: OutlineInputBorder(), isDense: true),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _keyHolderNoController,
            decoration: const InputDecoration(
              labelText: 'Key Holder Number (optional)',
              helperText: "Leave blank if you'll hand the key to a Key Controller instead",
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: _submitting ? null : _submitParkDetails,
              icon: const Icon(Icons.local_parking),
              label: Text(_submitting ? 'Saving...' : 'Save Parking Details'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard({required IconData icon, required MaterialColor color, required String title, required String message}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: color.shade800)),
                const SizedBox(height: 4),
                Text(message, style: TextStyle(fontSize: 13, color: color.shade700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
