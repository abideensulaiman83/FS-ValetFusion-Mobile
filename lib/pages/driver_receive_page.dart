// lib/pages/driver_receive_page.dart
//
// The Driver's full flow - one person, one continuous handoff, matching how the valet stand
// actually works: the Driver takes the car from the guest (scan the ticket while it's still
// FREE), photographs it so OCR fills in the plate/color/brand/model, links it to the ticket, is
// shown the nearest free parking slot, parks it there and confirms, then hands the physical key
// to the Key Controller. Previously this was split across a separate "Gate Scanner" role, but
// that meant two people/logins for what is really one driver's single trip with the car.



import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../components/barcode_scanner_page.dart';
import '../components/slot_picker.dart';
import '../components/wash_requests_section.dart';
import '../services/delivery_tracker.dart';
import '../services/ocr_service.dart';
import '../services/valet_service.dart';

class DriverReceiveFlow extends StatefulWidget {
  const DriverReceiveFlow({super.key});

  @override
  State<DriverReceiveFlow> createState() => _DriverReceiveFlowState();
}

// Shows any car a Key Controller has assigned to this driver, with full vehicle/ticket detail,
// and lets the driver mark it Arrived/Delivered - no need to already know the ticket number.
// The list, the background GPS and the 5-minute "Still on the way?" check all come from the
// app-level DeliveryTracker, so they keep running when this screen isn't showing.
class MyDeliveriesSection extends StatefulWidget {
  const MyDeliveriesSection({super.key});

  @override
  State<MyDeliveriesSection> createState() => _MyDeliveriesSectionState();
}

class _MyDeliveriesSectionState extends State<MyDeliveriesSection> {
  final ValetService _valetService = ValetService();
  final DeliveryTracker _tracker = DeliveryTracker.instance;
  final Set<int> _acting = {};

  @override
  void initState() {
    super.initState();
    _tracker.start();
  }

  Future<void> _act(TicketStatusResponse d, Future<void> Function(int id) action) async {
    if (d.parkingVehicleId == null) return;
    setState(() => _acting.add(d.parkingVehicleId!));
    try {
      await action(d.parkingVehicleId!);
      await _tracker.refresh();
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
    return ValueListenableBuilder<bool>(
      valueListenable: _tracker.loaded,
      builder: (context, loaded, _) {
        if (!loaded) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return ValueListenableBuilder<List<TicketStatusResponse>>(
          valueListenable: _tracker.deliveries,
          builder: (context, deliveries, _) {
            if (deliveries.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('My Deliveries',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.grey.shade800)),
                const SizedBox(height: 10),
                for (final d in deliveries) ...[
                  _buildDeliveryCard(d),
                  const SizedBox(height: 12),
                ],
                const Divider(height: 28),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDeliveryCard(TicketStatusResponse d) {
    final isActing = d.parkingVehicleId != null && _acting.contains(d.parkingVehicleId);
    final isArrived = d.status == 'ARRIVED';
    final car = [d.vehicleColor, d.vehicleMake, d.vehicleModel].where((s) => s != null && s.isNotEmpty).join(' ');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade50, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: d.checkInDue ? Colors.orange.shade400 : Colors.indigo.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.directions_car_filled, color: Colors.indigo.shade400),
              const SizedBox(width: 8),
              Expanded(
                child: Text(car.isEmpty ? 'Vehicle' : car,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
              Chip(
                label: Text(isArrived ? 'Arrived' : 'On the way',
                    style: const TextStyle(color: Colors.white, fontSize: 11)),
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
              if (d.keyHolderNo != null && d.keyHolderNo!.isNotEmpty) _detail('Key', d.keyHolderNo!),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.local_parking, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Expanded(
                child: Text(d.parkingLocation ?? (d.bayNo != null ? 'Bay ${d.bayNo}' : 'Parking spot not recorded'),
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade800, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          if (!isArrived && d.etaMinutes != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.schedule, size: 16, color: Colors.orange.shade700),
                const SizedBox(width: 4),
                Text(
                  d.etaMinutes! <= 0 ? 'Guest expects the car now' : 'Guest expects the car in ${d.etaMinutes} min',
                  style: TextStyle(fontSize: 13, color: Colors.orange.shade800, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => _tracker.promptCheckIn(d),
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  child: const Text('Update ETA'),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              if (!isArrived)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isActing ? null : () => _act(d, _valetService.arriveVehicle),
                    icon: const Icon(Icons.flag_outlined, size: 18),
                    label: const Text('Mark Arrived'),
                  ),
                ),
              if (!isArrived) const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isActing ? null : () => _act(d, _valetService.deliverVehicle),
                  icon: isActing
                      ? const SizedBox(
                          width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_circle_outline, size: 18),
                  label: Text(isActing ? 'Saving...' : 'Hand Over'),
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
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _vehicleColorController = TextEditingController();
  final _bayNoController = TextEditingController();
  final _keyHolderNoController = TextEditingController();
  final _slotPickerKey = GlobalKey<SlotPickerState>();

  bool _loading = false;
  TicketStatusResponse? _lastLookup;

  File? _vehicleImage;
  bool _ocrRunning = false;
  bool _ocrFilled = false;
  String? _ocrProblem;
  bool _submitting = false;
  AvailableSlot? _chosenSlot;

  @override
  void dispose() {
    _ticketNoController.dispose();
    _plateNoController.dispose();
    _brandController.dispose();
    _modelController.dispose();
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

  void _clearVehicleFields() {
    _plateNoController.clear();
    _brandController.clear();
    _modelController.clear();
    _vehicleColorController.clear();
    _bayNoController.clear();
    _keyHolderNoController.clear();
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
      _ocrFilled = false;
      _ocrProblem = null;
      _chosenSlot = null;
    });
    try {
      final data = await _valetService.checkTicketStatus(ticketNo);
      setState(() => _lastLookup = data);
      _clearVehicleFields();
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
      _ocrFilled = false;
      _ocrProblem = null;
    });

    try {
      final result = await _ocrService.recognize(file);
      if (!mounted) return;
      if (result.reason == 'no_vehicle_detected') {
        setState(() => _ocrProblem = 'No vehicle found in the photo - retake it, or type the details below.');
        return;
      }
      // Only the four things the desk needs - plate, color, brand, model. Keep anything the
      // driver already typed if OCR couldn't read that part.
      void fill(TextEditingController c, String? value) {
        if (value != null && value.trim().isNotEmpty) c.text = value.trim();
      }

      setState(() {
        fill(_plateNoController, result.plate?.raw ?? result.plate?.display);
        fill(_vehicleColorController, _capitalize(result.color?.name));
        fill(_brandController, result.vehicle?.brand);
        fill(_modelController, result.vehicle?.model);
        _ocrFilled = true;
        if (result.plate == null) _ocrProblem = 'Plate not readable - please type it.';
      });
    } catch (e) {
      if (mounted) setState(() => _ocrProblem = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _ocrRunning = false);
    }
  }

  String _capitalize(String? s) {
    if (s == null || s.isEmpty) return '';
    return s[0].toUpperCase() + s.substring(1);
  }

  String? _textOrNull(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _submitReceive() async {
    final ticketNo = _ticketNoController.text.trim();
    if (_plateNoController.text.trim().isEmpty) {
      _showSnack('Please enter the Plate Number (or take a photo first)', error: true);
      return;
    }

    setState(() => _submitting = true);
    try {
      await _valetService.receiveVehicle(
        ticketNo: ticketNo,
        plateNo: _plateNoController.text.trim(),
        vehicleMake: _textOrNull(_brandController),
        vehicleModel: _textOrNull(_modelController),
        vehicleColor: _textOrNull(_vehicleColorController),
        requestedRemarks: 'Received by driver (OCR-assisted)',
      );
      _showSnack('Vehicle linked to ticket $ticketNo - park it in the slot shown below.');
      // Refresh the lookup so the flow drops into the "park it here" step below.
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
    final slot = _chosenSlot;
    if (slot == null && _bayNoController.text.trim().isEmpty) {
      _showSnack('Pick a slot or type the bay where you parked', error: true);
      return;
    }

    setState(() => _submitting = true);
    try {
      final message = await _valetService.recordParkDetails(
        parkingVehicleId: data.parkingVehicleId!,
        slotId: slot?.slotId,
        bayNo: slot == null ? _bayNoController.text.trim() : null,
        keyHolderNo: _textOrNull(_keyHolderNoController),
      );
      _showSnack(_keyHolderNoController.text.trim().isEmpty
          ? '$message. Hand the key to the Key Controller.'
          : '$message, key holder ${_keyHolderNoController.text.trim()}.');
      _resetFlow();
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      _showSnack(msg, error: true);
      // Someone else took the slot a moment ago - show the next nearest one.
      if (msg.contains('just taken')) _slotPickerKey.currentState?.reload();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _resetFlow() {
    _ticketNoController.clear();
    _clearVehicleFields();
    setState(() {
      _lastLookup = null;
      _vehicleImage = null;
      _ocrFilled = false;
      _ocrProblem = null;
      _chosenSlot = null;
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
              message: 'Ticket ${data.ticketNo} is parked at ${data.parkingLocation ?? 'bay ${data.bayNo}'}'
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
            'Scan when taking the car from the guest - you will then be shown where to park it.',
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
          const Text('Photograph the Vehicle', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            'Plate, color, brand and model are filled in from the photo.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          if (_vehicleImage != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(_vehicleImage!, height: 180, width: double.infinity, fit: BoxFit.cover),
            ),
          if (_ocrProblem != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.error_outline, size: 18, color: Colors.orange.shade800),
                const SizedBox(width: 6),
                Expanded(child: Text(_ocrProblem!, style: TextStyle(fontSize: 13, color: Colors.orange.shade900))),
              ],
            ),
          ],
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
                  ? 'Reading the car...'
                  : (_vehicleImage == null ? 'Take Photo' : 'Retake Photo')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiveConfirmCard() {
    InputDecoration field(String label) =>
        InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true);
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
              const Text('Vehicle Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const Spacer(),
              if (_ocrFilled)
                Text('From photo - check', style: TextStyle(fontSize: 12, color: Colors.green.shade700)),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _plateNoController,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 1),
            decoration: field('Plate *'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _vehicleColorController,
            textCapitalization: TextCapitalization.words,
            decoration: field('Color'),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _brandController,
                  textCapitalization: TextCapitalization.words,
                  decoration: field('Brand'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _modelController,
                  textCapitalization: TextCapitalization.words,
                  decoration: field('Model'),
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
    final car = [data.vehicleColor, data.vehicleMake, data.vehicleModel].where((s) => s != null && s.isNotEmpty).join(' ');
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
          const Text('Park the Car', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('Ticket ${data.ticketNo} · ${data.plateNo ?? 'plate unknown'}${car.isEmpty ? '' : ' · $car'}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          const SizedBox(height: 14),
          SlotPicker(
            key: _slotPickerKey,
            bayController: _bayNoController,
            onChanged: (slot) => _chosenSlot = slot,
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
              label: Text(_submitting ? 'Saving...' : 'Parked Here - Confirm'),
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
