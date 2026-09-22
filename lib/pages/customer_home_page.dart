// lib/pages/customer_home_page.dart
//
// The Customer's own screen after logging in: enter/scan their ticket, see live status in
// plain language, and request their car when it's ready to be requested. Polls the same
// ticket-status endpoint staff use, just role-gated to the guest's own JWT (CUSTOMER role).
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../components/barcode_scanner_page.dart';
import '../components/confirm_dialog.dart';
import '../components/live_tracking_card.dart';
import '../services/authentication_service.dart';
import '../services/valet_service.dart';
import 'customer_history_page.dart';

class CustomerHomePage extends StatefulWidget {
  const CustomerHomePage({super.key});

  @override
  State<CustomerHomePage> createState() => _CustomerHomePageState();
}

class _CustomerHomePageState extends State<CustomerHomePage> {
  final _valetService = ValetService();
  final _authService = AuthenticationService();
  final _ticketNoController = TextEditingController();

  bool _loading = false;
  bool _requesting = false;
  bool _requestingWash = false;
  bool _autoLoading = true;
  TicketStatusResponse? _status;
  Timer? _pollTimer;

  // Multi-property support: a guest's account is tied to the hotel they signed up at, but they
  // may hand in/request a car at a *different* property on a later visit. `_selectedLocation`
  // null means "use my home property" (the default, no header override needed); set means the
  // app sends X-Company-Code on every ticket-related call so the backend searches that other
  // property's database instead - see ValetService._headers and JwtAuthenticationFilter.
  List<PublicCompanyOption> _locations = [];
  String? _homeTenantCode;
  PublicCompanyOption? _selectedLocation;
  bool _detectingLocation = false;

  // Real GPS accuracy (especially indoors, at a hotel entrance) is commonly 20-50m off, so a
  // strict 50m radius would too often miss a genuine match. 100m stays tight enough to tell
  // distinct nearby properties apart while tolerating that error.
  static const double _proximityRadiusMeters = 100;

  String? get _lookupCompanyCode =>
      (_selectedLocation != null && _selectedLocation!.code != _homeTenantCode) ? _selectedLocation!.code : null;

  @override
  void initState() {
    super.initState();
    _loadMyActiveTicket();
    _initLocationPicker();
  }

  Future<void> _initLocationPicker() async {
    final user = await _authService.getCurrentUser();
    _homeTenantCode = user?.tenantCode;
    try {
      _locations = await _authService.fetchPublicCompanies();
    } catch (_) {
      // Non-fatal - manual picker just shows empty until retried.
    }
    await _tryAutoDetectLocation();
  }

  // Pure detection - returns the nearest property within radius, or null (GPS denied/unavailable/
  // no match). Used both for the silent auto-detect on page load and the picker sheet's
  // "Detect automatically" button, so both share the exact same matching logic.
  Future<PublicCompanyOption?> _detectNearestLocation() async {
    if (_locations.isEmpty) return null;
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return null;
      if (!await Geolocator.isLocationServiceEnabled()) return null;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 8)),
      );

      PublicCompanyOption? nearest;
      double nearestDistance = double.infinity;
      for (final loc in _locations) {
        if (loc.pickupLat == null || loc.pickupLng == null) continue;
        final d = Geolocator.distanceBetween(position.latitude, position.longitude, loc.pickupLat!, loc.pickupLng!);
        if (d < nearestDistance) {
          nearestDistance = d;
          nearest = loc;
        }
      }
      return (nearest != null && nearestDistance <= _proximityRadiusMeters) ? nearest : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _tryAutoDetectLocation() async {
    if (mounted) setState(() => _detectingLocation = true);
    final nearest = await _detectNearestLocation();
    if (nearest != null && mounted) {
      setState(() => _selectedLocation = nearest);
    }
    if (mounted) setState(() => _detectingLocation = false);
  }

  Future<void> _showLocationPicker() async {
    final result = await showModalBottomSheet<_LocationPickResult>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _LocationPickerSheet(
        locations: _locations,
        homeTenantCode: _homeTenantCode,
        current: _selectedLocation,
        onDetect: _detectNearestLocation,
      ),
    );
    if (result == null) return;
    setState(() {
      _selectedLocation = result.location;
      // A different property means a different database - any ticket/status pulled under the
      // old selection no longer applies.
      _status = null;
      _ticketNoController.clear();
      _pollTimer?.cancel();
    });
  }

  Widget _buildLocationBar() {
    final label = _selectedLocation?.name ?? 'My property';
    return InkWell(
      onTap: _showLocationPicker,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.blue.shade100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.place_outlined, size: 15, color: Colors.blue.shade700),
            const SizedBox(width: 5),
            if (_detectingLocation)
              const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
            else
              Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.blue.shade800)),
            const SizedBox(width: 4),
            Icon(Icons.expand_more, size: 16, color: Colors.blue.shade700),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _ticketNoController.dispose();
    super.dispose();
  }

  // Shows "their" ticket automatically on open, without asking for the ticket number, once
  // they've looked it up (or requested pickup) at least once before - see
  // AuthService/ParkingVehicleService.linkCustomerIfUnset on the backend.
  Future<void> _loadMyActiveTicket() async {
    setState(() => _autoLoading = true);
    try {
      final data = await _valetService.fetchMyActiveTicket();
      if (data != null && mounted) {
        setState(() {
          _status = data;
          _ticketNoController.text = data.ticketNo;
        });
        _startPolling();
        _maybePromptRating(data);
      }
    } catch (_) {
      // Non-fatal - falls back to manual entry below.
    } finally {
      if (mounted) setState(() => _autoLoading = false);
    }
  }

  void _showSnack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? Colors.red.shade700 : Colors.green.shade700,
    ));
  }

  Future<void> _scanTicket() async {
    final scanned = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerPage(title: 'Scan Your Ticket')),
    );
    if (scanned != null && scanned.trim().isNotEmpty) {
      _ticketNoController.text = scanned.trim();
      await _lookup();
    }
  }

  Future<void> _lookup() async {
    final ticketNo = _ticketNoController.text.trim();
    if (ticketNo.isEmpty) {
      _showSnack('Enter or scan your ticket number', error: true);
      return;
    }
    setState(() => _loading = true);
    try {
      final data = await _valetService.checkTicketStatus(ticketNo, companyCode: _lookupCompanyCode);
      setState(() => _status = data);
      _startPolling();
      _maybePromptRating(data);
    } catch (e) {
      _showTicketLookupError(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // A "ticket not found"/"not used yet" message is an everyday, expected outcome on a customer
  // portal (wrong digit, first-time use, wrong property) - not an error to alarm anyone with, so
  // it gets its own calmer dialog instead of a red error snackbar.
  void _showTicketLookupError(Object e) {
    final message = e.toString().replaceAll('Exception: ', '');
    final lower = message.toLowerCase();
    if (lower.contains('not found') || lower.contains('not used') || lower.contains('free')) {
      _showFriendlyTicketDialog(
        icon: Icons.confirmation_number_outlined,
        color: Colors.blue,
        title: "We couldn't find that ticket",
        message: "Double check the number, or make sure you've picked the right property above.",
      );
      return;
    }
    _showSnack(message, error: true);
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) => _refreshStatus());
  }

  Future<void> _refreshStatus() async {
    final ticketNo = _ticketNoController.text.trim();
    if (ticketNo.isEmpty) return;
    try {
      final data = await _valetService.checkTicketStatus(ticketNo, companyCode: _lookupCompanyCode);
      if (mounted) setState(() => _status = data);
      if (data.status == 'DELIVERED') {
        _pollTimer?.cancel();
        _maybePromptRating(data);
      }
    } catch (_) {
      // silent - next tick tries again
    }
  }

  Future<void> _showFriendlyTicketDialog({
    required IconData icon,
    required MaterialColor color,
    required String title,
    required String message,
  }) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: Icon(icon, color: color.shade600, size: 32),
              ),
              const SizedBox(height: 16),
              Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center, style: TextStyle(fontSize: 13.5, color: Colors.grey.shade600, height: 1.4)),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  style: ElevatedButton.styleFrom(backgroundColor: color.shade600),
                  child: const Text('Got it'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // A plain parking system usually stops caring the moment the car leaves - asking for a quick
  // rating right after delivery is a small but real differentiator. Shown once per screen visit,
  // never re-shown if the guest already rated (data.rating != null) or dismissed it.
  bool _ratingPromptShown = false;
  void _maybePromptRating(TicketStatusResponse data) {
    if (data.status != 'DELIVERED' || data.rating != null || _ratingPromptShown) return;
    _ratingPromptShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showRatingDialog(data);
    });
  }

  Future<void> _showRatingDialog(TicketStatusResponse data) async {
    int selected = 5;
    final commentController = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('How was your experience?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    final starIndex = i + 1;
                    return IconButton(
                      onPressed: () => setDialogState(() => selected = starIndex),
                      icon: Icon(
                        starIndex <= selected ? Icons.star : Icons.star_border,
                        color: Colors.amber.shade600,
                        size: 32,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: commentController,
                  decoration: const InputDecoration(hintText: 'Any comments? (optional)', border: OutlineInputBorder()),
                  maxLines: 2,
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Skip')),
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  if (data.parkingVehicleId == null) return;
                  try {
                    await _valetService.submitRating(
                      parkingVehicleId: data.parkingVehicleId!,
                      rating: selected,
                      comment: commentController.text.trim().isEmpty ? null : commentController.text.trim(),
                      companyCode: _lookupCompanyCode,
                    );
                    _showSnack('Thanks for your feedback!');
                  } catch (_) {}
                },
                child: const Text('Submit'),
              ),
            ],
          );
        });
      },
    );
  }

  Future<void> _requestWash() async {
    final data = _status;
    if (data == null || data.parkingVehicleId == null) return;
    setState(() => _requestingWash = true);
    try {
      await _valetService.requestWash(data.parkingVehicleId!, companyCode: _lookupCompanyCode);
      _showSnack('Wash requested - the team has been notified.');
      _refreshStatus();
    } catch (e) {
      _showSnack(e.toString().replaceAll('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _requestingWash = false);
    }
  }

  Widget _buildWashRow(TicketStatusResponse data) {
    final washStatus = data.washStatus ?? 'NONE';
    if (washStatus == 'NONE') {
      return SizedBox(
        width: double.infinity,
        height: 44,
        child: OutlinedButton.icon(
          onPressed: _requestingWash ? null : _requestWash,
          icon: const Icon(Icons.local_car_wash_outlined),
          label: Text(_requestingWash ? 'Requesting...' : 'Request a Wash'),
        ),
      );
    }
    final labels = {
      'REQUESTED': 'Wash requested - waiting for a driver',
      'IN_PROGRESS': 'Your car is being washed',
      'DONE': 'Wash complete',
    };
    final colors = {
      'REQUESTED': Colors.orange,
      'IN_PROGRESS': Colors.blue,
      'DONE': Colors.green,
    };
    final color = colors[washStatus] ?? Colors.grey;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Icon(Icons.local_car_wash, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(labels[washStatus] ?? washStatus, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13))),
        ],
      ),
    );
  }

  Future<void> _requestPickup() async {
    final data = _status;
    if (data == null || data.parkingVehicleId == null) return;

    // Payable parking - ask how the guest intends to settle before the request goes to the
    // lobby desk, so they see the choice up front instead of finding out at handover.
    String? paymentMethod;
    final charge = data.parkingCharge ?? 0;
    if (charge > 0) {
      paymentMethod = await _choosePaymentMethod(charge);
      if (paymentMethod == null) return; // guest cancelled
    }

    setState(() => _requesting = true);
    try {
      await _valetService.requestVehicle(
        parkingVehicleId: data.parkingVehicleId!,
        requestedRemarks: 'Requested by guest via app',
        parkingCharge: charge,
        paymentMethod: paymentMethod,
        companyCode: _lookupCompanyCode,
      );
      _showSnack('Your car has been requested!');
      _refreshStatus();
    } catch (e) {
      _showSnack(e.toString().replaceAll('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  Future<String?> _choosePaymentMethod(double charge) async {
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Payment Method'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Parking charge: AED ${charge.toStringAsFixed(2)}'),
            const SizedBox(height: 12),
            const Text('How would you like to pay at the lobby desk?'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop('CASH'),
            icon: const Icon(Icons.payments_outlined),
            label: const Text('Cash'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop('CARD'),
            icon: const Icon(Icons.credit_card),
            label: const Text('Card'),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Log out?',
      message: "You'll need to sign in again to continue.",
      confirmLabel: 'Log out',
      destructive: true,
    );
    if (!confirmed) return;
    _pollTimer?.cancel();
    await _authService.logoutApi();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  String _friendlyMessage(String? status) {
    switch (status) {
      case 'RECEIVED':
        return 'Your vehicle is safely parked.';
      case 'REQUESTED':
        return "We've received your request - a valet is on the way to get your vehicle.";
      case 'ONTHEWAY':
        return 'Your vehicle is on its way to you now.';
      case 'ARRIVED':
        return "Your vehicle has arrived and is waiting for you.";
      case 'DELIVERED':
        return 'Your vehicle has been delivered. Thank you!';
      default:
        return 'Status updated.';
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'RECEIVED':
        return Colors.blue;
      case 'REQUESTED':
      case 'ONTHEWAY':
        return Colors.orange;
      case 'ARRIVED':
      case 'DELIVERED':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }


  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _logout();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6FB),
        appBar: AppBar(
          title: const Text('My Valet'),
          actions: [
            IconButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CustomerHistoryPage())),
              icon: const Icon(Icons.history),
              tooltip: 'My Parking History',
            ),
            IconButton(
              onPressed: () => Navigator.of(context).pushNamed('/privacy-policy'),
              icon: const Icon(Icons.privacy_tip_outlined),
              tooltip: 'Privacy & Policy',
            ),
            IconButton(onPressed: _logout, icon: const Icon(Icons.logout), tooltip: 'Logout'),
          ],
        ),
        body: SafeArea(
          child: _autoLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
            onRefresh: _status != null ? _refreshStatus : _loadMyActiveTicket,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(alignment: Alignment.centerLeft, child: _buildLocationBar()),
                  const SizedBox(height: 12),
                  if (_status != null) ...[
                    _buildStatusCard(_status!),
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton.icon(
                        onPressed: () {
                          _pollTimer?.cancel();
                          _ticketNoController.clear();
                          setState(() => _status = null);
                        },
                        icon: const Icon(Icons.confirmation_number_outlined, size: 18),
                        label: const Text('Track a different ticket'),
                      ),
                    ),
                  ] else
                    _buildLookupCard(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLookupCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Track Your Vehicle', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Enter or scan your ticket number to see live status.', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          const SizedBox(height: 16),
          TextField(
            controller: _ticketNoController,
            enabled: !_loading,
            decoration: const InputDecoration(
              labelText: 'Ticket Number',
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
                  onPressed: _loading ? null : _scanTicket,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _loading ? null : _lookup,
                  child: _loading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Check Status'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(TicketStatusResponse data) {
    if (data.ticketFree) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.amber.shade50, Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.amber.shade200),
        ),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: Colors.amber.shade100, shape: BoxShape.circle),
              child: Icon(Icons.info_outline_rounded, color: Colors.amber.shade800, size: 28),
            ),
            const SizedBox(height: 14),
            const Text("This ticket hasn't been used yet", style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              'No vehicle has been checked in against this ticket at ${_selectedLocation?.name ?? 'this property'} yet.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4),
            ),
          ],
        ),
      );
    }

    final color = _statusColor(data.status);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withValues(alpha: 0.12), Colors.white],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.35)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
                    child: Icon(Icons.directions_car, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(data.status ?? '-', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: color)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(_friendlyMessage(data.status), style: const TextStyle(fontSize: 14)),
              if (data.plateNo != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                  child: Text('${data.vehicleColor ?? ''} ${data.vehicleMake ?? ''} · ${data.plateNo}'.trim(),
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ],
              if (data.paymentMethod != null && data.paymentMethod!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('Payment: ${data.paymentMethod}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              ],
              if (data.status == 'RECEIVED') ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _requesting ? null : _requestPickup,
                    icon: const Icon(Icons.local_shipping_outlined),
                    label: Text(_requesting ? 'Requesting...' : 'Request My Car'),
                  ),
                ),
                const SizedBox(height: 10),
                _buildWashRow(data),
              ],
            ],
          ),
        ),
        if (data.status == 'ONTHEWAY') ...[
          const SizedBox(height: 14),
          LiveTrackingCard(data: data),
        ],
      ],
    );
  }
}

// Wraps the picker's result so "no selection" (dismissed) and "explicitly picked home property"
// are distinguishable - both null-ish otherwise.
class _LocationPickResult {
  final PublicCompanyOption? location;
  const _LocationPickResult(this.location);
}

class _LocationPickerSheet extends StatefulWidget {
  final List<PublicCompanyOption> locations;
  final String? homeTenantCode;
  final PublicCompanyOption? current;
  final Future<PublicCompanyOption?> Function() onDetect;

  const _LocationPickerSheet({
    required this.locations,
    required this.homeTenantCode,
    required this.current,
    required this.onDetect,
  });

  @override
  State<_LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<_LocationPickerSheet> {
  bool _detecting = false;
  bool _noMatchFound = false;

  Future<void> _detect() async {
    setState(() {
      _detecting = true;
      _noMatchFound = false;
    });
    final nearest = await widget.onDetect();
    if (!mounted) return;
    if (nearest != null) {
      final isHome = nearest.code == widget.homeTenantCode;
      Navigator.of(context).pop(_LocationPickResult(isHome ? null : nearest));
      return;
    }
    setState(() {
      _detecting = false;
      _noMatchFound = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.35,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
                ),
                const SizedBox(height: 16),
                const Text('Which property are you at?', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  'Picking a property looks up tickets there instead of your home property.',
                  style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: _detecting ? null : _detect,
                  icon: _detecting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.my_location, size: 18),
                  label: Text(_detecting ? 'Detecting...' : 'Detect automatically (GPS)'),
                ),
                if (_noMatchFound) ...[
                  const SizedBox(height: 8),
                  Text(
                    "Couldn't detect a property nearby - please pick one below.",
                    style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
                  ),
                ],
                const SizedBox(height: 10),
                Expanded(
                  child: widget.locations.isEmpty
                      ? Center(child: Text('No properties available.', style: TextStyle(color: Colors.grey.shade500)))
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: widget.locations.length,
                          itemBuilder: (context, index) {
                            final loc = widget.locations[index];
                            final isHome = loc.code == widget.homeTenantCode;
                            final isSelected = widget.current?.code == loc.code || (widget.current == null && isHome);
                            return ListTile(
                              onTap: () => Navigator.of(context).pop(_LocationPickResult(isHome ? null : loc)),
                              leading: Icon(
                                isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                                color: isSelected ? Colors.blue.shade600 : Colors.grey.shade400,
                              ),
                              title: Text(loc.name),
                              subtitle: isHome ? const Text('Your property', style: TextStyle(fontSize: 12)) : null,
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
