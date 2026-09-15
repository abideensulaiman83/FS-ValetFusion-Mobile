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
import '../components/layout/app_layout.dart';
import '../components/live_tracking_card.dart';
import '../components/wash_requests_section.dart';
import '../services/authentication_service.dart';
import '../services/valet_service.dart';
import 'driver_receive_page.dart';

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
  List<Shop> _shopsList = [];
  List<ServiceType> _serviceTypesList = [];

  // "New Vehicle Entry" form - only shown for a FREE ticket on the full desk.
  bool _showEntryForm = false;
  final _vpaInController = TextEditingController();
  final _plateNoController = TextEditingController();
  final _vehicleMakeController = TextEditingController();
  final _vehicleColorController = TextEditingController();
  final _bayNoController = TextEditingController();
  final _commentsController = TextEditingController();
  int? _selectedServiceTypeId;

  @override
  void initState() {
    super.initState();
    _loadRoles();
    _fetchDashboard();
    _fetchLookups();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _ticketNoFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _ticketNoController.dispose();
    _ticketNoFocusNode.dispose();
    _vpaInController.dispose();
    _plateNoController.dispose();
    _vehicleMakeController.dispose();
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
  }

  Future<void> _fetchDashboard() async {
    try {
      final data = await _valetService.fetchDashboardDetails();
      if (mounted) setState(() => _dashboard = data);
    } catch (_) {
      // Non-fatal - the stat strip just stays empty; the scan flow doesn't depend on it.
    }
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

  void _showSnack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? Colors.red.shade700 : Colors.green.shade700,
    ));
  }

  void _resetEntryForm() {
    _vpaInController.clear();
    _plateNoController.clear();
    _vehicleMakeController.clear();
    _vehicleColorController.clear();
    _bayNoController.clear();
    _commentsController.clear();
    setState(() {
      _showEntryForm = false;
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
          await _openRequestDialog(data);
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
    if (ticketNo.isEmpty) missing.add('Ticket Number');
    if (_vpaInController.text.trim().isEmpty) missing.add('VPA-In');
    if (_plateNoController.text.trim().isEmpty) missing.add('Plate Number');
    if (_selectedServiceTypeId == null) missing.add('Service Type');

    if (missing.isNotEmpty) {
      _showSnack('Please fill: ${missing.join(', ')}', error: true);
      return;
    }

    setState(() => _loading = true);
    try {
      await _valetService.receiveVehicle(
        ticketNo: ticketNo,
        vpaIn: _vpaInController.text.trim(),
        plateNo: _plateNoController.text.trim(),
        bayNo: _bayNoController.text.trim().isEmpty ? null : _bayNoController.text.trim(),
        vehicleMake: _vehicleMakeController.text.trim().isEmpty ? null : _vehicleMakeController.text.trim(),
        vehicleColor: _vehicleColorController.text.trim().isEmpty ? null : _vehicleColorController.text.trim(),
        serviceType: _selectedServiceTypeId,
        requestedRemarks: _commentsController.text.trim().isEmpty ? null : _commentsController.text.trim(),
      );
      _showSnack('Vehicle received successfully!');
      _ticketNoController.clear();
      _resetEntryForm();
      _fetchDashboard();
      _ticketNoFocusNode.requestFocus();
    } catch (e) {
      _showSnack(e.toString().replaceAll('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
              await _valetService.requestVehicle(
                parkingVehicleId: data.parkingVehicleId!,
                requestedRemarks: 'Vehicle Requested',
                parkingCharge: parkingCharge,
                shopId: selectedShopId,
                shopRemarks: shopRemarksController.text.trim(),
                paymentMethod: paymentMethod,
              );
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              _showSnack('Vehicle requested successfully!');
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
            title: const Text('Payment Details'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _kv('Ticket No', data.ticketNo),
                  _kv('Plate No', data.plateNo ?? '-'),
                  _kv('Parking Charge', parkingCharge.toStringAsFixed(2)),
                  const SizedBox(height: 12),
                  const Text('Outlet', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  if (isShopValidated)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green.shade700, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Validated at ${data.shopName ?? 'Shop'}'
                              '${data.shopValidateTime != null ? ' • ${data.shopValidateTime}' : ''}',
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
                        const DropdownMenuItem<int?>(value: null, child: Text('-- Select Outlet --')),
                        ..._shopsList.map((s) => DropdownMenuItem<int?>(value: s.id, child: Text(s.shopName))),
                      ],
                      onChanged: onOutletChange,
                    ),
                  if (!isShopValidated && selectedShopId != null) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: shopRemarksController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Shop Remarks',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: 'Payment Method  ', style: TextStyle(fontWeight: FontWeight.w600)),
                        if (parkingCharge > 0) const TextSpan(text: '*', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: paymentMethod,
                    decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('-- Select Payment Method --')),
                      const DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                      if (parkingCharge > 0) const DropdownMenuItem(value: 'Card', child: Text('Card')),
                    ],
                    onChanged: (v) => setDialogState(() => paymentMethod = v),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: dialogLoading ? null : onRequest,
                child: dialogLoading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Request'),
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
              await _valetService.dispatchVehicle(
                parkingVehicleId: data.parkingVehicleId!,
                driverId: manualEntry ? null : selectedDriver!.id,
                vpaOut: manualEntry ? vpaOutController.text.trim() : null,
              );
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              _showSnack('Vehicle dispatched successfully!');
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
            title: const Text('Dispatch Vehicle'),
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
                    decoration: const InputDecoration(
                      labelText: 'Assign Driver',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: drivers
                        .map((d) => DropdownMenuItem(value: d, child: Text(d.name)))
                        .toList(),
                    onChanged: (v) => setDialogState(() => selectedDriver = v),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => setDialogState(() => manualEntry = true),
                    child: const Text('Enter Employee ID manually instead'),
                  ),
                ] else
                  TextField(
                    controller: vpaOutController,
                    decoration: const InputDecoration(
                      labelText: 'Employee ID',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: dialogLoading ? null : onDispatch,
                child: dialogLoading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Dispatch'),
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
              await _valetService.arriveVehicle(data.parkingVehicleId!);
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              _showSnack('Arrival acknowledged - waiting for guest handover.');
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
            title: const Text('Acknowledge Arrival'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.local_shipping, color: Colors.indigo.shade400, size: 40),
                const SizedBox(height: 12),
                const Text(
                  'Has this vehicle physically arrived at the lobby?',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ticket No: ${data.ticketNo} - confirming here just marks it as waiting for '
                  'the guest; you\'ll still confirm the actual handover next.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                if (data.driverLat != null) ...[
                  const SizedBox(height: 14),
                  LiveTrackingCard(data: data),
                ],
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: dialogLoading ? null : onArrived,
                child: dialogLoading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Arrived'),
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

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(builder: (context, setDialogState) {
          Future<void> onDelivered() async {
            setDialogState(() => dialogLoading = true);
            try {
              await _valetService.deliverVehicle(data.parkingVehicleId!);
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              _showSnack('Vehicle delivered successfully!');
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
            title: const Text('Confirm Delivery'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.directions_car, color: Colors.green.shade600, size: 40),
                const SizedBox(height: 12),
                const Text(
                  'Are you sure you want to mark this vehicle as delivered?',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text('Ticket No: ${data.ticketNo}', style: TextStyle(color: Colors.grey.shade600)),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: dialogLoading ? null : onDelivered,
                child: dialogLoading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Delivered'),
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
          Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
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
      return const AppLayout(
        title: 'Driver Desk',
        child: DriverReceiveFlow(),
      );
    }
    return AppLayout(
      title: 'Valet Desk',
      child: RefreshIndicator(
        onRefresh: () async {
          await _fetchDashboard();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
      ),
    );
  }

  Widget _buildStatStrip() {
    final d = _dashboard;
    final chips = <Widget>[
      _statChip('Received', d?.receivedCount.toString() ?? '-', Colors.cyan),
      _statChip('Delivered', d?.deliveredCount.toString() ?? '-', Colors.indigo),
      _statChip('In Inventory', d?.currentInventory.toString() ?? '-', Colors.blue),
      _statChip('Complimentary', d?.complimentaryCount.toString() ?? '-', Colors.green),
      _statChip('Paid', d?.paidCount.toString() ?? '-', Colors.amber),
      if (d != null && d.ticketsTotal > 0)
        _statChip('Tickets Free', '${d.ticketsRemaining}/${d.ticketsTotal}',
            d.ticketsRemaining / d.ticketsTotal <= 0.15 ? Colors.red : Colors.grey),
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

  Widget _statChip(String label, String value, MaterialColor color) {
    return Container(
      width: 108,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color.shade700)),
          Text(label, style: TextStyle(fontSize: 11, color: color.shade700), overflow: TextOverflow.ellipsis),
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
          Text(
            _isSimplifiedDesk ? 'Scan Ticket' : 'Scan / New Vehicle Entry',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ticketNoController,
            focusNode: _ticketNoFocusNode,
            enabled: !_loading,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Ticket Number',
              hintText: 'Enter or scan ticket number',
              prefixIcon: Icon(Icons.confirmation_number_outlined),
              border: OutlineInputBorder(),
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
              label: Text(_loading ? 'Checking...' : 'Submit'),
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
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('New Vehicle Entry', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          TextField(
            controller: _vpaInController,
            decoration: const InputDecoration(labelText: 'VPA-In *', border: OutlineInputBorder(), isDense: true),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _plateNoController,
            decoration:
                const InputDecoration(labelText: 'Plate Number *', border: OutlineInputBorder(), isDense: true),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<int>(
            value: _selectedServiceTypeId,
            decoration: const InputDecoration(labelText: 'Service Type *', border: OutlineInputBorder(), isDense: true),
            items: _serviceTypesList
                .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name)))
                .toList(),
            onChanged: (v) => setState(() => _selectedServiceTypeId = v),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _bayNoController,
            decoration: const InputDecoration(labelText: 'Bay Number', border: OutlineInputBorder(), isDense: true),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _vehicleMakeController,
                  decoration:
                      const InputDecoration(labelText: 'Vehicle Model', border: OutlineInputBorder(), isDense: true),
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
          const SizedBox(height: 10),
          TextField(
            controller: _commentsController,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Comments', border: OutlineInputBorder(), isDense: true),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _loading ? null : _resetEntryForm,
                  child: const Text('Clear'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _loading ? null : _saveEntry,
                  child: Text(_loading ? 'Saving...' : 'Save Entry'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleList(String title, List<Map<String, dynamic>> items, {required bool isOnTheWay}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Text('$title (${items.length})', style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16, left: 14),
              child: Text('No ${title.toLowerCase()} vehicles', style: TextStyle(color: Colors.grey.shade500)),
            )
          else
            ...items.map((v) {
              final ticketNo = v['ticketNo']?.toString() ?? '';
              final status = v['status']?.toString();
              return ListTile(
                dense: true,
                leading: const Icon(Icons.directions_car, size: 20),
                title: Text('Ticket $ticketNo · ${v['plateNo'] ?? '-'}'),
                subtitle: Text(isOnTheWay
                    ? (status == 'ARRIVED' ? 'Arrived' : 'On the way')
                    : 'Requested at ${v['requestedTime'] ?? '-'}'),
                trailing: isOnTheWay && status == 'ARRIVED'
                    ? Chip(
                        label: const Text('Arrived', style: TextStyle(fontSize: 11)),
                        backgroundColor: Colors.green.shade50,
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      )
                    : null,
                onTap: () => _tapListItem(ticketNo),
              );
            }),
        ],
      ),
    );
  }
}
