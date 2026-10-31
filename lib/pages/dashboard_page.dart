// lib/pages/dashboard_page.dart
//
// The real Valet Desk screen - ported from the web app's core workflow
// (frontend/FS-ValetFusion/src/pages/DashboardPage.tsx): scan a ticket, then branch on its
// status (FREE -> receive; RECEIVED -> request; REQUESTED -> dispatch; ONTHEWAY -> acknowledge
// arrival; ARRIVED -> confirm delivery), against the same backend contract as the web and
// desktop-Lobby flow (POST /v1/parking-vehicles/{id}/arrive, etc). Role-aware: LOBBY and
// KEY_CONTROLLER get the simplified scan-only desk (no "receive a new vehicle" form), matching
// isSimplifiedDesk on the web.




import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../components/condition_photos.dart';
import '../components/desk_board.dart';
import '../components/guest_tracking_qr_sheet.dart';
import '../components/key_tag.dart';
import '../components/layout/app_layout.dart';
import '../components/live_tracking_card.dart';
import '../components/pending_sync_banner.dart';
import '../components/slot_picker.dart';
import '../components/undo_step_dialog.dart';
import '../components/wash_requests_section.dart';
import '../services/authentication_service.dart';
import '../services/offline_queue.dart';
import '../services/desk_links.dart';
import '../services/valet_service.dart';
import 'condition_compare_page.dart';
import 'driver_receive_page.dart';
import 'parking_occupancy_page.dart';
import '../theme/app_theme.dart';
import '../l10n/app_strings.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final ValetService _valetService = ValetService();

  final _ticketNoController = TextEditingController();
  final _ticketNoFocusNode = FocusNode();

  bool _isSimplifiedDesk = false; // LOBBY or KEY_CONTROLLER
  bool _isDriver = false;
  bool _rolesLoaded = false;

  bool _loading = false;
  DashboardDetails? _dashboard;
  // Received and still parked - the step before Requested, listed alongside it.
  List<TicketStatusResponse> _parked = [];
  List<Shop> _shopsList = [];
  List<ServiceType> _serviceTypesList = [];

  // "New Vehicle Entry" form - only shown for a FREE ticket on the full desk.
  bool _showEntryForm = false;
  final _vpaInController = TextEditingController();
  final _plateNoController = TextEditingController();
  final _vehicleMakeController = TextEditingController();
  final _vehicleModelController = TextEditingController();
  final _vehicleColorController = TextEditingController();
  final _bayNoController = TextEditingController();
  final _commentsController = TextEditingController();
  int? _selectedServiceTypeId;
  AvailableSlot? _entrySlot; // slot picked in the entry form; null = typed bay / none

  @override
  void initState() {
    super.initState();
    _loadRoles();
    _fetchDashboard();
    _fetchLookups();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _ticketNoFocusNode.requestFocus();
      _openLinkedTicket();
    });
    DeskLinks.pendingTicket.addListener(_openLinkedTicket);
  }

  // A notification asked for a ticket (see notifications_inbox_page.dart) - look it up.
  void _openLinkedTicket() {
    if (!mounted || !_rolesLoaded || _isDriver || DeskLinks.pendingTicket.value == null) return;
    _ticketNoController.text = DeskLinks.take()!;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _lookupTicket();
    });
  }

  @override
  void dispose() {
    DeskLinks.pendingTicket.removeListener(_openLinkedTicket);
    _ticketNoController.dispose();
    _ticketNoFocusNode.dispose();
    _vpaInController.dispose();
    _plateNoController.dispose();
    _vehicleMakeController.dispose();
    _vehicleModelController.dispose();
    _vehicleColorController.dispose();
    _bayNoController.dispose();
    _commentsController.dispose();
    super.dispose();
  }

  Future<void> _loadRoles() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString(AuthenticationService.userKey);
    if (userStr == null) return;
    final roles = List<String>.from(jsonDecode(userStr)['roles'] ?? []);
    setState(() {
      _isSimplifiedDesk = roles.contains('LOBBY') || roles.contains('KEY_CONTROLLER');
      _isDriver = roles.contains('DRIVER') || roles.contains('GATE_SCANNER');
      _rolesLoaded = true;
    });
    _openLinkedTicket();
  }

  Future<void> _fetchDashboard() async {
    try {
      final data = await _valetService.fetchDashboardDetails();
      if (mounted) setState(() => _dashboard = data);
    } catch (_) {
      // Non-fatal - the stat strip just stays empty; the scan flow doesn't depend on it.
    }
    try {
      final parked = await _valetService.fetchByStatus('RECEIVED');
      // Newest first - the car just taken from the guest is the one staff are looking for.
      parked.sort((a, b) => (b.parkingInTime ?? '').compareTo(a.parkingInTime ?? ''));
      if (mounted) setState(() => _parked = parked);
    } catch (_) {}
  }

  Future<void> _fetchLookups() async {
    try {
      final shops = await _valetService.fetchShops();
      if (mounted) setState(() => _shopsList = shops);
    } catch (_) {}
    try {
      final types = await _valetService.fetchServiceTypes();
      if (mounted) {
        setState(() {
          _serviceTypesList = types;
          if (types.isNotEmpty) _selectedServiceTypeId = types.first.id;
        });
      }
    } catch (_) {}
  }

  // [message] is an English key (translated here, after the mounted check) or a server message
  // (no Arabic entry, so it shows as-is).
  void _showSnack(String message, {bool error = false, Map<String, Object?> args = const {}}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(tr(context, message, args)),
      backgroundColor: error ? context.vf.danger : context.vf.success,
    ));
  }

  // Every desk step goes through the offline queue (plan E13): sent now with an Idempotency-Key,
  // or - with no signal - kept on the phone and sent automatically with that same key.
  Future<SendOutcome> _send(String type, int parkingVehicleId, String label, [Map<String, dynamic> extra = const {}]) =>
      OfflineQueue.instance.sendOrQueue(type: type, payload: {'parkingVehicleId': parkingVehicleId, ...extra}, label: label);

  void _queuedSnack(String what, [Map<String, Object?> args = const {}]) {
    if (!mounted) return;
    _showSnack('No signal - {what} saved on this phone and will be sent automatically.', args: {'what': tr(context, what, args)});
  }

  // Key tag QR on a car that's already in: scan the hook's tag and save it as the key holder.
  Future<String?> _scanAndSetKeyHolder(TicketStatusResponse data) async {
    if (data.parkingVehicleId == null) return null;
    final tag = await scanKeyTag(context);
    if (tag == null) return null;
    try {
      final outcome = await _send('key_holder', data.parkingVehicleId!, 'Key holder $tag for ticket ${data.ticketNo}',
          {'keyHolderNo': tag});
      outcome.queued
          ? _queuedSnack('key holder {tag}', {'tag': tag})
          : _showSnack('Ticket {no}: key holder set to {tag}', args: {'no': data.ticketNo, 'tag': tag});
      return tag;
    } catch (e) {
      _showSnack(e.toString().replaceAll('Exception: ', ''), error: true);
      return null;
    }
  }

  // Undo last step (mistaken request / dispatch / arrival / handover) - see undo_step_dialog.dart.
  Future<void> _undoStep(TicketStatusResponse data, String status) async {
    if (data.parkingVehicleId == null) return;
    final message = await showUndoStepDialog(context,
        parkingVehicleId: data.parkingVehicleId!, ticketNo: data.ticketNo, plateNo: data.plateNo, status: status);
    if (message == null) return;
    _showSnack(message);
    _ticketNoController.clear();
    _fetchDashboard();
    _ticketNoFocusNode.requestFocus();
  }

  void _resetEntryForm() {
    _vpaInController.clear();
    _plateNoController.clear();
    _vehicleMakeController.clear();
    _vehicleModelController.clear();
    _vehicleColorController.clear();
    _bayNoController.clear();
    _commentsController.clear();
    setState(() {
      _showEntryForm = false;
      _entrySlot = null;
      if (_serviceTypesList.isNotEmpty) _selectedServiceTypeId = _serviceTypesList.first.id;
    });
  }

  Future<void> _lookupTicket() async {
    final ticketNo = _ticketNoController.text.trim();
    if (ticketNo.isEmpty) return;

    setState(() => _loading = true);
    try {
      final data = await _valetService.checkTicketStatus(ticketNo);

      if (data.ticketFree) {
        if (_isSimplifiedDesk) {
          _showSnack('This ticket has not been received yet.');
          return;
        }
        setState(() => _showEntryForm = true);
        return;
      }

      switch (data.status) {
        case 'RECEIVED':
          // Key just handed over and nobody has recorded where the car is yet - mark the slot
          // first; otherwise carry on to the request/payment step as before.
          if ((data.bayNo == null || data.bayNo!.trim().isEmpty) && data.parkingLocation == null) {
            await _openParkSheet(data);
          } else {
            await _openRequestDialog(data);
          }
          break;
        case 'REQUESTED':
          await _openDispatchDialog(data);
          break;
        case 'ONTHEWAY':
          await _openArrivalDialog(data);
          break;
        case 'ARRIVED':
          await _openDeliveryDialog(data);
          break;
        case 'DELIVERED':
          _showSnack('This ticket has already been delivered!');
          break;
      }
    } catch (e) {
      _showSnack(e.toString().replaceAll('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveEntry() async {
    final ticketNo = _ticketNoController.text.trim();
    final missing = <String>[];
    if (ticketNo.isEmpty) missing.add(tr(context, 'Ticket Number'));
    if (_vpaInController.text.trim().isEmpty) missing.add(tr(context, 'VPA-In'));
    if (_plateNoController.text.trim().isEmpty) missing.add(tr(context, 'Plate Number'));
    if (_selectedServiceTypeId == null) missing.add(tr(context, 'Service Type'));

    if (missing.isNotEmpty) {
      _showSnack('Please fill: {fields}', args: {'fields': missing.join(', ')}, error: true);
      return;
    }

    setState(() => _loading = true);
    try {
      await _valetService.receiveVehicle(
        ticketNo: ticketNo,
        vpaIn: _vpaInController.text.trim(),
        plateNo: _plateNoController.text.trim(),
        bayNo: _entrySlot != null || _bayNoController.text.trim().isEmpty ? null : _bayNoController.text.trim(),
        vehicleMake: _vehicleMakeController.text.trim().isEmpty ? null : _vehicleMakeController.text.trim(),
        vehicleModel: _vehicleModelController.text.trim().isEmpty ? null : _vehicleModelController.text.trim(),
        vehicleColor: _vehicleColorController.text.trim().isEmpty ? null : _vehicleColorController.text.trim(),
        serviceType: _selectedServiceTypeId,
        requestedRemarks: _commentsController.text.trim().isEmpty ? null : _commentsController.text.trim(),
      );
      final slot = _entrySlot;
      if (slot != null) {
        // Claim the chosen slot for the car we just received.
        try {
          final received = await _valetService.checkTicketStatus(ticketNo);
          final message = await _valetService.recordParkDetails(
            parkingVehicleId: received.parkingVehicleId!,
            slotId: slot.slotId,
          );
          _showSnack('Vehicle received - {message}', args: {'message': message});
        } catch (e) {
          _showSnack('Vehicle received, but the slot was not saved: {error}. Scan the ticket again to pick a slot.',
              args: {'error': e.toString().replaceAll('Exception: ', '')}, error: true);
        }
      } else {
        _showSnack('Vehicle received successfully!');
      }
      final vehicleText = [
        _vehicleColorController.text.trim(),
        _vehicleMakeController.text.trim(),
        _vehicleModelController.text.trim(),
        _plateNoController.text.trim(),
      ].where((s) => s.isNotEmpty).join(' · ');
      _ticketNoController.clear();
      _resetEntryForm();
      _fetchDashboard();
      // Guest is still at the stand - let them scan straight to this car's live status.
      if (mounted) await GuestTrackingQr.show(context, ticketNo: ticketNo, vehicleText: vehicleText);
      _ticketNoFocusNode.requestFocus();
    } catch (e) {
      _showSnack(e.toString().replaceAll('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Every received (parked) car - where it is, since when, and its guest QR - one tap from the
  // desk for drivers, lobby and key controllers, not just the admin home.
  Widget _parkedAction() => IconButton(
        icon: const Icon(Icons.vpn_key_outlined),
        tooltip: tr(context, 'Received vehicles'),
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ParkingOccupancyPage())),
      );

  // ── Park sheet (RECEIVED, no slot yet) ─────────────────────────────────
  // The Key Controller (or desk) records where the car was parked: the nearest free slot is
  // pre-selected, or they pick another / type a bay.
  Future<void> _openParkSheet(TicketStatusResponse data) async {
    if (data.parkingVehicleId == null) return;
    final bayController = TextEditingController();
    final keyController = TextEditingController(text: data.keyHolderNo ?? '');
    final pickerKey = GlobalKey<SlotPickerState>();
    AvailableSlot? slot;
    bool saving = false;
    final car = [data.vehicleColor, data.vehicleMake, data.vehicleModel].where((s) => s != null && s.isNotEmpty).join(' ');

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(builder: (context, setSheetState) {
        Future<void> save() async {
          if (slot == null && bayController.text.trim().isEmpty) {
            _showSnack('Pick a slot or type the bay', error: true);
            return;
          }
          setSheetState(() => saving = true);
          try {
            final outcome = await _send('park_details', data.parkingVehicleId!, 'Parking location for ticket ${data.ticketNo}', {
              if (slot != null) 'slotId': slot!.slotId,
              if (slot == null) 'bayNo': bayController.text.trim(),
              if (keyController.text.trim().isNotEmpty) 'keyHolderNo': keyController.text.trim(),
            });
            if (sheetContext.mounted) Navigator.of(sheetContext).pop();
            outcome.queued
                ? _queuedSnack('parking for ticket {no}', {'no': data.ticketNo})
                : (outcome.message == null
                    ? _showSnack('Ticket {no}: Parked', args: {'no': data.ticketNo})
                    : _showSnack('Ticket {no}: {message}', args: {'no': data.ticketNo, 'message': outcome.message}));
            _ticketNoController.clear();
            _ticketNoFocusNode.requestFocus();
          } catch (e) {
            final msg = e.toString().replaceAll('Exception: ', '');
            _showSnack(msg, error: true);
            if (msg.contains('just taken')) pickerKey.currentState?.reload();
          } finally {
            if (context.mounted) setSheetState(() => saving = false);
          }
        }

        return Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(tr(context, 'Where is this car parked?'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('${tr(context, 'Ticket {no}', {'no': data.ticketNo})} · ${data.plateNo ?? '-'}${car.isEmpty ? '' : ' · $car'}',
                    style: TextStyle(color: context.vf.textSecondary)),
                const SizedBox(height: 16),
                SlotPicker(key: pickerKey, bayController: bayController, onChanged: (s) => slot = s),
                const SizedBox(height: 10),
                TextField(
                  controller: keyController,
                  decoration: InputDecoration(
                    labelText: tr(context, 'Key Holder Number'),
                    border: const OutlineInputBorder(),
                    isDense: true,
                    suffixIcon: ScanKeyTagSuffix(controller: keyController),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: saving ? null : save,
                    icon: const Icon(Icons.local_parking),
                    label: Text(tr(context, saving ? 'Saving...' : 'Save Parking Location')),
                  ),
                ),
                TextButton(
                  onPressed: saving
                      ? null
                      : () {
                          Navigator.of(sheetContext).pop();
                          _openRequestDialog(data);
                        },
                  child: Text(tr(context, 'Skip - request the car instead')),
                ),
              ],
            ),
          ),
        );
      }),
    );
    bayController.dispose();
    keyController.dispose();
  }

  // ── Request dialog (RECEIVED -> REQUESTED) ──────────────────────────────
  Future<void> _openRequestDialog(TicketStatusResponse data) async {
    int? selectedShopId = data.shopId;
    final bool isShopValidated = data.shopId != null;
    double parkingCharge = data.parkingCharge ?? 0;
    final originalCharge = data.originalParkingCharge ?? data.parkingCharge ?? 0;
    String? paymentMethod;
    final shopRemarksController = TextEditingController(text: data.shopRemarks ?? '');
    bool dialogLoading = false;
    String? keyHolder = data.keyHolderNo;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(builder: (context, setDialogState) {
          Future<void> onOutletChange(int? shopId) async {
            setDialogState(() => selectedShopId = shopId);
            if (shopId == null || data.parkingVehicleId == null) {
              setDialogState(() => parkingCharge = originalCharge);
              return;
            }
            try {
              final charge = await _valetService.previewShopCharge(
                parkingVehicleId: data.parkingVehicleId!,
                shopId: shopId,
              );
              setDialogState(() => parkingCharge = charge);
            } catch (e) {
              _showSnack(e.toString().replaceAll('Exception: ', ''), error: true);
              setDialogState(() {
                selectedShopId = null;
                parkingCharge = originalCharge;
              });
            }
          }

          Future<void> onRequest() async {
            if (parkingCharge > 0 && (paymentMethod == null || paymentMethod!.isEmpty)) {
              _showSnack('Please select a payment method (Cash / Card)', error: true);
              return;
            }
            setDialogState(() => dialogLoading = true);
            try {
              final outcome = await _send('request', data.parkingVehicleId!, 'Request for ticket ${data.ticketNo}', {
                'requestedRemarks': 'Vehicle Requested',
                'parkingCharge': parkingCharge,
                if (selectedShopId != null) 'shopId': selectedShopId,
                'shopRemarks': shopRemarksController.text.trim(),
                if (paymentMethod != null) 'paymentMethod': paymentMethod,
              });
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              outcome.queued
                  ? _queuedSnack('the request for ticket {no}', {'no': data.ticketNo})
                  : _showSnack('Vehicle requested successfully!');
              _ticketNoController.clear();
              _fetchDashboard();
              _ticketNoFocusNode.requestFocus();
            } catch (e) {
              _showSnack(e.toString().replaceAll('Exception: ', ''), error: true);
            } finally {
              setDialogState(() => dialogLoading = false);
            }
          }

          return AlertDialog(
            title: Text(tr(context, 'Payment Details')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _kv('Ticket No', data.ticketNo),
                  _kv('Plate No', data.plateNo ?? '-'),
                  _kv('Parking Charge', parkingCharge.toStringAsFixed(2)),
                  Row(
                    children: [
                      Text(tr(context, 'Key hook'), style: TextStyle(color: context.vf.textSecondary, fontSize: 13)),
                      const Spacer(),
                      Text(keyHolder == null || keyHolder!.isEmpty ? '-' : keyHolder!,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      IconButton(
                        tooltip: tr(context, 'Scan key tag'),
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.qr_code_scanner, size: 20),
                        onPressed: dialogLoading
                            ? null
                            : () async {
                                final tag = await _scanAndSetKeyHolder(data);
                                if (tag != null) setDialogState(() => keyHolder = tag);
                              },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(tr(context, 'Outlet'), style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  if (isShopValidated)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.vf.successSoft,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: context.vf.successSoft),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: context.vf.success, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              tr(context, 'Validated at {shop}', {'shop': data.shopName ?? tr(context, 'Shop')}) +
                                  (data.shopValidateTime != null ? ' • ${data.shopValidateTime}' : ''),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    DropdownButtonFormField<int?>(
                      value: selectedShopId,
                      decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                      items: [
                        DropdownMenuItem<int?>(value: null, child: Text(tr(context, '-- Select Outlet --'))),
                        ..._shopsList.map((s) => DropdownMenuItem<int?>(value: s.id, child: Text(s.shopName))),
                      ],
                      onChanged: onOutletChange,
                    ),
                  if (!isShopValidated && selectedShopId != null) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: shopRemarksController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: tr(context, 'Shop Remarks'),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: '${tr(context, 'Payment Method')}  ', style: const TextStyle(fontWeight: FontWeight.w600)),
                        if (parkingCharge > 0) TextSpan(text: '*', style: TextStyle(color: context.vf.danger)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: paymentMethod,
                    decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                    items: [
                      DropdownMenuItem(value: null, child: Text(tr(context, '-- Select Payment Method --'))),
                      DropdownMenuItem(value: 'Cash', child: Text(tr(context, 'Cash'))),
                      if (parkingCharge > 0) DropdownMenuItem(value: 'Card', child: Text(tr(context, 'Card'))),
                    ],
                    onChanged: (v) => setDialogState(() => paymentMethod = v),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(tr(context, 'Cancel'))),
              ElevatedButton(
                onPressed: dialogLoading ? null : onRequest,
                child: dialogLoading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(tr(context, 'Request')),
              ),
            ],
          );
        });
      },
    );
  }

  // ── Dispatch dialog (REQUESTED -> ONTHEWAY) ─────────────────────────────
  // Key Controller assigns any available Driver from the list, instead of typing a free-text
  // employee ID - falls back to manual entry if no drivers are returned (e.g. none active yet).
  Future<void> _openDispatchDialog(TicketStatusResponse data) async {
    final vpaOutController = TextEditingController();
    bool dialogLoading = false;
    bool driversLoading = true;
    List<DriverOption> drivers = [];
    DriverOption? selectedDriver;
    bool manualEntry = false;

    try {
      drivers = await _valetService.fetchAvailableDrivers();
      selectedDriver = drivers.where((d) => d.suggested).firstOrNull;
    } catch (_) {
      // Non-fatal - just falls back to manual entry below.
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(builder: (context, setDialogState) {
          driversLoading = false;
          if (drivers.isEmpty) manualEntry = true;

          Future<void> onDispatch() async {
            if (!manualEntry && selectedDriver == null) {
              _showSnack('Please select a driver', error: true);
              return;
            }
            if (manualEntry && vpaOutController.text.trim().isEmpty) {
              _showSnack('Please enter Employee ID', error: true);
              return;
            }
            setDialogState(() => dialogLoading = true);
            try {
              final outcome = await _send('dispatch', data.parkingVehicleId!, 'Dispatch of ticket ${data.ticketNo}', {
                if (!manualEntry) 'driverId': selectedDriver!.id,
                if (manualEntry) 'vpaOut': vpaOutController.text.trim(),
              });
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              outcome.queued
                  ? _queuedSnack('the dispatch of ticket {no}', {'no': data.ticketNo})
                  : _showSnack('Vehicle dispatched successfully!');
              _ticketNoController.clear();
              _fetchDashboard();
              _ticketNoFocusNode.requestFocus();
            } catch (e) {
              _showSnack(e.toString().replaceAll('Exception: ', ''), error: true);
            } finally {
              setDialogState(() => dialogLoading = false);
            }
          }

          return AlertDialog(
            title: Text(tr(context, 'Dispatch Vehicle')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _kv('Ticket No', data.ticketNo),
                _kv('Plate No', data.plateNo ?? '-'),
                if (data.paymentMethod != null && data.paymentMethod!.isNotEmpty)
                  _kv('Payment', data.paymentMethod!),
                const SizedBox(height: 12),
                if (driversLoading)
                  const Center(child: CircularProgressIndicator())
                else if (!manualEntry) ...[
                  DropdownButtonFormField<DriverOption>(
                    value: selectedDriver,
                    decoration: InputDecoration(
                      labelText: tr(context, 'Assign Driver'),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    // On-duty drivers come first (server order); break / off duty are marked.
                    items: drivers
                        .map((d) => DropdownMenuItem(
                              value: d,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: d.offDuty
                                          ? context.vf.textSecondary
                                          : (d.onBreak ? context.vf.warning : context.vf.success),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text('${d.name}  (${d.loadLabel})',
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(color: d.offDuty ? context.vf.textSecondary : null)),
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                    onChanged: (v) => setDialogState(() => selectedDriver = v),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => setDialogState(() => manualEntry = true),
                    child: Text(tr(context, 'Enter Employee ID manually instead')),
                  ),
                ] else
                  TextField(
                    controller: vpaOutController,
                    decoration: InputDecoration(
                      labelText: tr(context, 'Employee ID'),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton.icon(
                onPressed: dialogLoading ? null : () { Navigator.of(dialogContext).pop(); _undoStep(data, 'REQUESTED'); },
                icon: const Icon(Icons.undo, size: 18),
                label: Text(tr(context, 'Undo request')),
                style: TextButton.styleFrom(foregroundColor: context.vf.textSecondary),
              ),
              TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(tr(context, 'Cancel'))),
              ElevatedButton(
                onPressed: dialogLoading ? null : onDispatch,
                child: dialogLoading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(tr(context, 'Dispatch')),
              ),
            ],
          );
        });
      },
    );
  }

  // ── Acknowledge Arrival dialog (ONTHEWAY -> ARRIVED) ────────────────────
  Future<void> _openArrivalDialog(TicketStatusResponse data) async {
    bool dialogLoading = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(builder: (context, setDialogState) {
          Future<void> onArrived() async {
            setDialogState(() => dialogLoading = true);
            try {
              final outcome = await _send('arrive', data.parkingVehicleId!, 'Arrival of ticket ${data.ticketNo}');
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              outcome.queued
                  ? _queuedSnack('the arrival of ticket {no}', {'no': data.ticketNo})
                  : _showSnack('Arrival acknowledged - waiting for guest handover.');
              _ticketNoController.clear();
              _fetchDashboard();
              _ticketNoFocusNode.requestFocus();
            } catch (e) {
              _showSnack(e.toString().replaceAll('Exception: ', ''), error: true);
            } finally {
              setDialogState(() => dialogLoading = false);
            }
          }

          return AlertDialog(
            title: Text(tr(context, 'Acknowledge Arrival')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.local_shipping, color: context.vf.live, size: 40),
                const SizedBox(height: 12),
                Text(
                  tr(context, 'Has this vehicle physically arrived at the lobby?'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  tr(context, "Ticket No: {no} - confirming here just marks it as waiting for the guest; you'll still confirm the actual handover next.",
                      {'no': data.ticketNo}),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: context.vf.textSecondary),
                ),
                if (data.parkingVehicleId != null) ConditionPhotosStrip(parkingVehicleId: data.parkingVehicleId!),
                if (data.driverLat != null) ...[
                  const SizedBox(height: 14),
                  LiveTrackingCard(data: data),
                ],
              ],
            ),
            actions: [
              TextButton.icon(
                onPressed: dialogLoading ? null : () { Navigator.of(dialogContext).pop(); _undoStep(data, 'ONTHEWAY'); },
                icon: const Icon(Icons.undo, size: 18),
                label: Text(tr(context, 'Undo dispatch')),
                style: TextButton.styleFrom(foregroundColor: context.vf.textSecondary),
              ),
              TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(tr(context, 'Cancel'))),
              ElevatedButton(
                onPressed: dialogLoading ? null : onArrived,
                child: dialogLoading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(tr(context, 'Arrived')),
              ),
            ],
          );
        });
      },
    );
  }

  // ── Confirm Delivery dialog (ARRIVED, or ONTHEWAY direct -> DELIVERED) ──
  Future<void> _openDeliveryDialog(TicketStatusResponse data) async {
    bool dialogLoading = false;
    bool? keyChecked; // null: not scanned; true: tag matched; false: mismatch / no hook on record

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(builder: (context, setDialogState) {
          Future<void> onDelivered() async {
            setDialogState(() => dialogLoading = true);
            try {
              final outcome = await _send('deliver', data.parkingVehicleId!, 'Handover of ticket ${data.ticketNo}');
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              if (outcome.queued) {
                _queuedSnack('the handover of ticket {no}', {'no': data.ticketNo});
              } else if (mounted) {
                // this.context: the page - the dialog's own context is gone after the pop above.
                ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(
                  content: Text(tr(this.context, 'Ticket {no} delivered', {'no': data.ticketNo})),
                  backgroundColor: this.context.vf.success,
                  duration: const Duration(seconds: 12),
                  action: SnackBarAction(
                    label: tr(this.context, 'UNDO'),
                    textColor: AppColors.ink,
                    onPressed: () => _undoStep(data, 'DELIVERED'),
                  ),
                ));
              }
              _ticketNoController.clear();
              _fetchDashboard();
              _ticketNoFocusNode.requestFocus();
            } catch (e) {
              _showSnack(e.toString().replaceAll('Exception: ', ''), error: true);
            } finally {
              setDialogState(() => dialogLoading = false);
            }
          }

          return AlertDialog(
            title: Text(tr(context, 'Confirm Delivery')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.directions_car, color: context.vf.success, size: 40),
                const SizedBox(height: 12),
                Text(
                  tr(context, 'Are you sure you want to mark this vehicle as delivered?'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(tr(context, 'Ticket No: {no}', {'no': data.ticketNo}), style: TextStyle(color: context.vf.textSecondary)),
                const SizedBox(height: 8),
                // Scan the tag on the key in hand - warns if it's from another car's hook.
                OutlinedButton.icon(
                  onPressed: dialogLoading
                      ? null
                      : () async {
                          final ok = await verifyKeyTag(context, expected: data.keyHolderNo, ticketNo: data.ticketNo);
                          setDialogState(() => keyChecked = ok);
                        },
                  icon: Icon(
                    keyChecked == null ? Icons.qr_code_scanner : (keyChecked! ? Icons.verified_rounded : Icons.warning_amber_rounded),
                    color: keyChecked == null ? null : (keyChecked! ? context.vf.success : context.vf.danger),
                  ),
                  label: Text(keyChecked == null
                      ? tr(context, 'Scan key tag')
                      : (keyChecked!
                          ? tr(context, 'Key matches hook {hook}', {'hook': data.keyHolderNo})
                          : tr(context, 'Key not matched - scan again'))),
                ),
                // Compare against how the car came in before handing it over.
                if (data.parkingVehicleId != null) ConditionPhotosStrip(parkingVehicleId: data.parkingVehicleId!),
                ConditionCompareButton(data: data),
              ],
            ),
            actions: [
              TextButton.icon(
                onPressed: dialogLoading ? null : () { Navigator.of(dialogContext).pop(); _undoStep(data, 'ARRIVED'); },
                icon: const Icon(Icons.undo, size: 18),
                label: Text(tr(context, 'Undo arrival')),
                style: TextButton.styleFrom(foregroundColor: context.vf.textSecondary),
              ),
              TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(tr(context, 'Cancel'))),
              ElevatedButton(
                onPressed: dialogLoading ? null : onDelivered,
                child: dialogLoading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(tr(context, 'Delivered')),
              ),
            ],
          );
        });
      },
    );
  }

  Widget _kv(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(tr(context, label), style: TextStyle(color: context.vf.textSecondary, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }

  Future<void> _tapListItem(String ticketNo) async {
    _ticketNoController.text = ticketNo;
    await _lookupTicket();
  }

  @override
  Widget build(BuildContext context) {
    if (_isDriver) {
      return AppLayout(
        title: tr(context, 'Driver Desk'),
        actions: [_parkedAction()],
        child: const DriverReceiveFlow(),
      );
    }
    // Desk (scan + lists) and the live Board (Requested / On the way / At lobby with wait timers);
    // tapping a car on the Board opens the same dialog as scanning its ticket here.
    return AppLayout(
      title: tr(context, 'Valet Desk'),
      actions: [_parkedAction()],
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            Material(
              color: context.vf.card,
              child: TabBar(tabs: [
                Tab(icon: const Icon(Icons.qr_code_scanner, size: 20), text: tr(context, 'Desk'), iconMargin: const EdgeInsets.only(bottom: 2)),
                Tab(icon: const Icon(Icons.view_agenda_outlined, size: 20), text: tr(context, 'Board'), iconMargin: const EdgeInsets.only(bottom: 2)),
              ]),
            ),
            Expanded(
              child: TabBarView(
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildDesk(),
                  DeskBoard(onOpen: (ticketNo) async {
                    await _tapListItem(ticketNo);
                    _fetchDashboard();
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesk() {
    return RefreshIndicator(
      onRefresh: () async {
        await _fetchDashboard();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PendingSyncBanner(),
            if (_rolesLoaded) _buildStatStrip(),
            const SizedBox(height: 16),
            if (_isSimplifiedDesk) ...[
              const WashRequestsSection(),
            ],
            _buildScanCard(),
            if (_showEntryForm && !_isSimplifiedDesk) ...[
              const SizedBox(height: 16),
              _buildEntryForm(),
            ],
            const SizedBox(height: 16),
            _buildVehicleList('Requested', _dashboard?.requestedVehicles ?? [], isOnTheWay: false),
            const SizedBox(height: 16),
            _buildVehicleList('On The Way', _dashboard?.onthewayVehicles ?? [], isOnTheWay: true),
          ],
        ),
      ),
    );
  }

  Widget _buildStatStrip() {
    final d = _dashboard;
    final vf = context.vf;
    final chips = <Widget>[
      _statChip('Received', d?.receivedCount.toString() ?? '-', vf.live),
      _statChip('Delivered', d?.deliveredCount.toString() ?? '-', vf.live),
      _statChip('In Inventory', d?.currentInventory.toString() ?? '-', Theme.of(context).colorScheme.primary),
      _statChip('Complimentary', d?.complimentaryCount.toString() ?? '-', vf.success),
      _statChip('Paid', d?.paidCount.toString() ?? '-', vf.warning),
      if (d != null && d.ticketsTotal > 0)
        _statChip('Tickets Free', '${d.ticketsRemaining}/${d.ticketsTotal}',
            d.ticketsRemaining / d.ticketsTotal <= 0.15 ? vf.danger : vf.textSecondary),
    ];

    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => chips[i],
      ),
    );
  }

  Widget _statChip(String label, String value, Color color) {
    return Container(
      width: 108,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
          Text(tr(context, label), style: TextStyle(fontSize: 11, color: color), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildScanCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.vf.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.vf.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr(context, _isSimplifiedDesk ? 'Scan Ticket' : 'Scan / New Vehicle Entry'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ticketNoController,
            focusNode: _ticketNoFocusNode,
            enabled: !_loading,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: tr(context, 'Ticket Number'),
              hintText: tr(context, 'Enter or scan ticket number'),
              prefixIcon: const Icon(Icons.confirmation_number_outlined),
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => _lookupTicket(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _lookupTicket,
              icon: _loading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.search),
              label: Text(tr(context, _loading ? 'Checking...' : 'Submit')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.vf.accentSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.vf.accentSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr(context, 'New Vehicle Entry'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          TextField(
            controller: _vpaInController,
            decoration: InputDecoration(labelText: tr(context, 'VPA-In *'), border: const OutlineInputBorder(), isDense: true),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _plateNoController,
            decoration:
                InputDecoration(labelText: tr(context, 'Plate Number *'), border: const OutlineInputBorder(), isDense: true),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<int>(
            value: _selectedServiceTypeId,
            decoration: InputDecoration(labelText: tr(context, 'Service Type *'), border: const OutlineInputBorder(), isDense: true),
            items: _serviceTypesList
                .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name)))
                .toList(),
            onChanged: (v) => setState(() => _selectedServiceTypeId = v),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _vehicleMakeController,
                  decoration: InputDecoration(labelText: tr(context, 'Brand'), border: const OutlineInputBorder(), isDense: true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _vehicleModelController,
                  decoration: InputDecoration(labelText: tr(context, 'Model'), border: const OutlineInputBorder(), isDense: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _vehicleColorController,
            decoration: InputDecoration(labelText: tr(context, 'Color'), border: const OutlineInputBorder(), isDense: true),
          ),
          const SizedBox(height: 14),
          Text(tr(context, 'Parking slot'), style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          SlotPicker(bayController: _bayNoController, onChanged: (slot) => _entrySlot = slot),
          const SizedBox(height: 10),
          TextField(
            controller: _commentsController,
            maxLines: 2,
            decoration: InputDecoration(labelText: tr(context, 'Comments'), border: const OutlineInputBorder(), isDense: true),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _loading ? null : _resetEntryForm,
                  child: Text(tr(context, 'Clear')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _loading ? null : _saveEntry,
                  child: Text(tr(context, _loading ? 'Saving...' : 'Save Entry')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static const int _parkedPreview = 5;

  String _parkedFor(String? isoTime) {
    if (isoTime == null) return '';
    final start = DateTime.tryParse(isoTime);
    if (start == null) return '';
    final diff = DateTime.now().difference(start);
    if (diff.inHours >= 1) return tr(context, '{h}h {m}m', {'h': diff.inHours, 'm': diff.inMinutes % 60});
    return tr(context, '{m}m', {'m': diff.inMinutes});
  }

  // Received rows inside the Requested card. Violet = awaiting a slot, grey = parked; the
  // requested rows above keep their blue "Requested" chip.
  Widget _statusChip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
        child: Text(tr(context, label), style: TextStyle(color: AppTheme.contrastOn(color), fontSize: 10.5, fontWeight: FontWeight.w700)),
      );

  Color get _requestedColor => Theme.of(context).colorScheme.primary;
  Color get _awaitingSlotColor => context.vf.live;
  Color get _parkedColor => context.vf.textSecondary;

  List<Widget> _receivedTiles() {
    String? slotOf(TicketStatusResponse p) =>
        p.parkingLocation ?? (p.bayNo != null && p.bayNo!.isNotEmpty ? tr(context, 'Bay {bay}', {'bay': p.bayNo}) : null);
    // Awaiting a slot first - someone has to act on those.
    final ordered = [..._parked]..sort((a, b) => (slotOf(a) == null ? 0 : 1) - (slotOf(b) == null ? 0 : 1));
    return ordered.take(_parkedPreview).map((p) {
      final car = [p.vehicleColor, p.vehicleMake, p.vehicleModel].where((s) => s != null && s.isNotEmpty).join(' ');
      final slot = slotOf(p);
      final color = slot == null ? _awaitingSlotColor : _parkedColor;
      return Container(
        decoration: BoxDecoration(border: BorderDirectional(start: BorderSide(color: color, width: 3))),
        child: ListTile(
          dense: true,
          leading: Icon(slot == null ? Icons.hourglass_top : Icons.local_parking, size: 20, color: color),
          title: Text('${tr(context, 'Ticket {no}', {'no': p.ticketNo})} · ${p.plateNo ?? '-'}'),
          subtitle: Text([
            if (car.isNotEmpty) car,
            if (slot != null) slot,
            tr(context, 'received {time} ago', {'time': _parkedFor(p.parkingInTime)}),
          ].join(' · ')),
          trailing: _statusChip(slot == null ? 'Awaiting slot' : 'Parked', color),
          // Same as scanning the ticket: no slot yet -> record where it's parked, else request.
          onTap: () => _tapListItem(p.ticketNo),
        ),
      );
    }).toList();
  }

  Widget _buildVehicleList(String title, List<Map<String, dynamic>> items, {required bool isOnTheWay}) {
    return Container(
      decoration: BoxDecoration(
        color: context.vf.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.vf.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(14, isOnTheWay ? 14 : 6, 4, isOnTheWay ? 14 : 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                      isOnTheWay
                          ? '${tr(context, title)} (${items.length})'
                          : '${tr(context, title)} (${items.length}) · ${tr(context, 'Received')} (${_parked.length})',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                if (!isOnTheWay && _parked.length > _parkedPreview)
                  TextButton(
                    onPressed: () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => const ParkingOccupancyPage()))
                        .then((_) => _fetchDashboard()),
                    child: Text(tr(context, 'All received')),
                  )
                else if (!isOnTheWay)
                  const SizedBox(height: 40),
              ],
            ),
          ),
          if (items.isEmpty && (isOnTheWay || _parked.isEmpty))
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: 16, start: 14),
              child: Text(tr(context, isOnTheWay ? 'No vehicles on the way' : 'No requested or received vehicles'),
                  style: TextStyle(color: context.vf.textSecondary)),
            )
          else ...[
            ...items.map((v) {
              final ticketNo = v['ticketNo']?.toString() ?? '';
              final status = v['status']?.toString();
              return ListTile(
                dense: true,
                leading: const Icon(Icons.directions_car, size: 20),
                title: Text('${tr(context, 'Ticket {no}', {'no': ticketNo})} · ${v['plateNo'] ?? '-'}'),
                subtitle: Text(isOnTheWay
                    ? tr(context, status == 'ARRIVED' ? 'Arrived' : 'On the way')
                    : tr(context, 'Requested at {time}', {'time': v['requestedTime'] ?? '-'})),
                trailing: isOnTheWay && status == 'ARRIVED'
                    ? Chip(
                        label: Text(tr(context, 'Arrived'), style: const TextStyle(fontSize: 11)),
                        backgroundColor: context.vf.successSoft,
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      )
                    : isOnTheWay
                        ? null
                        : _statusChip('Requested', _requestedColor),
                onTap: () => _tapListItem(ticketNo),
              );
            }),
            if (!isOnTheWay) ..._receivedTiles(),
          ],
        ],
      ),
    );
  }
}
