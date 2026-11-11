// lib/pages/shop_home_page.dart
//
// Home for an outlet (shop) login - role SHOP_VALIDATOR - ported from the web ShopValidatePage
// (frontend/FS-ValetFusion/src/pages/ShopValidatePage.tsx). Type or scan a ticket, see the car,
// whether an outlet already validated it and the price that applies, then do what this outlet may
// (GET /v1/shops/mine):
// - validate (canValidate) - and, for validate + request outlets, request the car while the charge
//   with this outlet is 0;
// - request-only outlets (canRequest, no canValidate) request any parked car; the guest pays the
//   applicable charge at the valet desk.
// An outlet with Mobile Access switched off sees only that message. The server enforces every
// rule again; its refusals (403 / 409 / 400) are shown as they come.
import 'package:flutter/material.dart';
import '../components/barcode_scanner_page.dart';
import '../components/confirm_dialog.dart';
import '../components/layout/app_layout.dart';
import '../l10n/app_strings.dart';
import '../services/authentication_service.dart';
import '../services/shop_service.dart';
import '../services/valet_service.dart';
import '../theme/app_theme.dart';

class ShopHomePage extends StatefulWidget {
  const ShopHomePage({super.key});

  @override
  State<ShopHomePage> createState() => _ShopHomePageState();
}

enum _Busy { validate, request }

class _ShopHomePageState extends State<ShopHomePage> {
  final _shopApi = ShopService();
  final _valetApi = ValetService();
  final _ticketNoController = TextEditingController();
  final _remarksController = TextEditingController();

  MyShop? _shop;
  bool _shopLoading = true;
  String? _shopError; // English / server text, shown through tr()

  bool _looking = false;
  TicketStatusResponse? _ticket;
  String? _lookupError;
  _Busy? _busy;
  bool _validated = false; // validated for this outlet (just now, or before)
  bool _requested = false;
  String? _actionError;

  @override
  void initState() {
    super.initState();
    _loadShop();
  }

  @override
  void dispose() {
    _ticketNoController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  // The outlet and what it may do. Until it is known nothing can be looked up: Mobile Access and
  // the capabilities decide what this screen offers.
  Future<void> _loadShop() async {
    setState(() {
      _shopLoading = true;
      _shopError = null;
    });
    try {
      final shop = await _shopApi.fetchMine();
      if (!mounted) return;
      setState(() {
        _shop = shop;
        _syncValidated();
      });
    } catch (e) {
      if (mounted) setState(() => _shopError = shopErrorMessage(e, fallback: 'Could not load your outlet. Try again.'));
    } finally {
      if (mounted) setState(() => _shopLoading = false);
    }
  }

  // A ticket this outlet validated before counts as validated.
  void _syncValidated() {
    final t = _ticket, shop = _shop;
    if (t?.shopId != null && shop?.id != null && t!.shopId == shop!.id) _validated = true;
  }

  void _snack(String message, {bool error = false, bool info = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      duration: Duration(seconds: error ? 6 : 4),
      backgroundColor: info ? null : (error ? context.vf.danger : context.vf.success),
    ));
  }

  // A refused or failed action: kept on the card and shown in a snackbar.
  void _fail(String message) {
    if (!mounted) return;
    setState(() => _actionError = message);
    _snack(tr(context, message), error: true);
  }

  void _resetTicket() {
    _ticket = null;
    _lookupError = null;
    _actionError = null;
    _validated = false;
    _requested = false;
    _remarksController.clear();
  }

  // Done with this step: the ticket field is cleared for the next ticket; the card stays until then.
  void _readyForNext({bool clearRemarks = false}) {
    _ticketNoController.clear();
    if (clearRemarks) _remarksController.clear();
  }

  Future<void> _scanTicket() async {
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
      _snack(tr(context, 'Enter or scan a ticket number first'), error: true);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _looking = true;
      _resetTicket();
    });
    try {
      final data = await _valetApi.checkTicketStatus(ticketNo);
      if (!mounted) return;
      setState(() {
        _ticket = data;
        _syncValidated();
      });
    } catch (e) {
      if (mounted) setState(() => _lookupError = shopErrorMessage(e, fallback: 'Ticket not found'));
    } finally {
      if (mounted) setState(() => _looking = false);
    }
  }

  // Re-read the ticket (the charge with this outlet after validation). Null when it can't be read.
  Future<TicketStatusResponse?> _refresh(TicketStatusResponse v) async {
    try {
      final fresh = await _valetApi.checkTicketStatus(v.ticketNo);
      if (mounted) {
        setState(() {
          _ticket = fresh;
          _syncValidated();
        });
      }
      return fresh;
    } catch (_) {
      return null;
    }
  }

  Future<TicketStatusResponse?> _validate(TicketStatusResponse v) async {
    await _shopApi.validate(v.parkingVehicleId!, shopRemarks: _remarksController.text.trim());
    if (mounted) setState(() => _validated = true);
    return _refresh(v);
  }

  Future<void> _handleValidate() async {
    final v = _ticket;
    if (v == null || v.parkingVehicleId == null) return;
    setState(() {
      _busy = _Busy.validate;
      _actionError = null;
    });
    try {
      await _validate(v);
      if (!mounted) return;
      _snack(tr(context, 'Ticket {no} validated', {'no': v.ticketNo}));
      _readyForNext();
    } catch (e) {
      _fail(shopErrorMessage(e,
          conflict: 'This ticket was already validated or is no longer parked.', fallback: 'Validation failed'));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  // Validate + request outlet: validate if needed, re-read, and request only on the charge just
  // read back from the server (0 with this outlet).
  Future<void> _handleValidateAndRequest() async {
    final v = _ticket;
    if (v == null || v.parkingVehicleId == null) return;
    setState(() {
      _busy = _Busy.request;
      _actionError = null;
    });
    try {
      TicketStatusResponse? fresh = v;
      if (!_validated) {
        try {
          fresh = await _validate(v);
        } catch (e) {
          // 409 = already validated (possibly by this outlet before): re-read and go on.
          if (e is! ShopApiException || e.statusCode != 409) {
            _fail(shopErrorMessage(e,
                conflict: 'This ticket was already validated or is no longer parked.', fallback: 'Validation failed'));
            return;
          }
          fresh = await _refresh(v);
        }
      }
      if (fresh == null || fresh.status != 'RECEIVED' || fresh.parkingVehicleId == null) {
        _fail('This car is no longer parked, or the ticket could not be re-read - ask the valet desk.');
        return;
      }
      if (!isZeroCharge(fresh.shopCharge)) {
        if (mounted) {
          _snack(tr(context, 'This ticket has a charge with your shop - the guest pays and requests the car at the valet desk.'),
              info: true);
        }
        return;
      }
      final shop = _shop;
      final name = (shop != null && shop.name.isNotEmpty) ? shop.name : ((fresh.shopName ?? '').isNotEmpty ? fresh.shopName! : 'shop');
      await _shopApi.requestCar(
        fresh.parkingVehicleId!,
        shopId: shop?.id,
        paymentMethod: 'Shop validated',
        parkingCharge: 0,
        requestedRemarks: 'Requested by $name - shop validated',
        shopRemarks: _remarksController.text.trim(),
      );
      if (!mounted) return;
      setState(() => _requested = true);
      _snack(tr(context, 'Car requested for ticket {no}', {'no': fresh.ticketNo}));
      _readyForNext(clearRemarks: true);
    } catch (e) {
      _fail(shopErrorMessage(e,
          conflict: 'This car was already requested, or it now has a charge - ask the valet desk.',
          fallback: 'The car could not be requested'));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  // Request-only outlet: call for the car as it is; the server prices it and the guest pays at the desk.
  Future<void> _handleRequestOnly() async {
    final v = _ticket;
    if (v == null || v.parkingVehicleId == null) return;
    setState(() {
      _busy = _Busy.request;
      _actionError = null;
    });
    try {
      final remarks = _remarksController.text.trim();
      await _shopApi.requestCar(
        v.parkingVehicleId!,
        shopId: _shop?.id,
        requestedRemarks: remarks.isEmpty ? null : remarks,
        shopRemarks: remarks,
      );
      if (!mounted) return;
      setState(() => _requested = true);
      _snack(tr(context, 'Car requested for ticket {no}', {'no': v.ticketNo}));
      _readyForNext(clearRemarks: true);
    } catch (e) {
      _fail(shopErrorMessage(e,
          conflict: 'This car was already requested or is no longer parked - ask the valet desk.',
          fallback: 'The car could not be requested'));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _onRefresh() async {
    await _loadShop();
    final t = _ticket;
    if (t != null && _busy == null && !t.ticketFree && t.parkingVehicleId != null) await _refresh(t);
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
    await AuthenticationService().logoutApi();
    if (mounted) Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final shop = _shop;
    final title = (shop != null && shop.name.isNotEmpty) ? shop.name : tr(context, 'Validate tickets');
    return AppLayout(
      title: title,
      actions: [IconButton(onPressed: _logout, icon: const Icon(Icons.logout), tooltip: tr(context, 'Logout'))],
      child: RefreshIndicator(
        onRefresh: _onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _body(shop),
          ),
        ),
      ),
    );
  }

  List<Widget> _body(MyShop? shop) {
    if (shop == null) {
      if (_shopLoading) {
        return const [Padding(padding: EdgeInsets.only(top: 80), child: Center(child: CircularProgressIndicator()))];
      }
      return [
        _banner(Icons.cloud_off_rounded, context.vf.danger, context.vf.dangerSoft, tr(context, _shopError ?? 'Could not load your outlet. Try again.')),
        const SizedBox(height: 12),
        OutlinedButton.icon(onPressed: _loadShop, icon: const Icon(Icons.refresh), label: Text(tr(context, 'Retry'))),
      ];
    }
    // Contract: Mobile Access off = this message only.
    if (!shop.mobile) {
      return [
        const SizedBox(height: 24),
        _banner(Icons.phonelink_off_rounded, context.vf.warning, context.vf.warningSoft,
            tr(context, 'Mobile access is switched off for this outlet - please use the web console.')),
      ];
    }
    final t = _ticket;
    return [
      if (_shopError != null) ...[
        _banner(Icons.cloud_off_rounded, context.vf.danger, context.vf.dangerSoft, tr(context, _shopError!)),
        const SizedBox(height: 12),
      ],
      _buildScanCard(shop),
      if (_lookupError != null) ...[
        const SizedBox(height: 16),
        _banner(Icons.error_outline, context.vf.danger, context.vf.dangerSoft, tr(context, _lookupError!)),
      ],
      if (t != null) ...[
        const SizedBox(height: 16),
        if (t.ticketFree || t.ticketStatus == 'FREE')
          _banner(Icons.info_outline, context.vf.live, context.vf.infoSoft, tr(context, 'This ticket is not in use'))
        else if (t.parkingVehicleId == null)
          _banner(Icons.info_outline, context.vf.warning, context.vf.warningSoft,
              t.message.isNotEmpty ? tr(context, t.message) : tr(context, 'No parking record for this ticket - ask the valet desk.'))
        else
          _buildTicketCard(shop, t),
      ],
    ];
  }

  Widget _buildScanCard(MyShop shop) {
    final enabled = !_looking && _busy == null;
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
          Row(children: [
            Icon(Icons.storefront_rounded, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(tr(context, 'Scan Ticket'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 4),
          Text(
            tr(context, shop.requestOnly
                ? 'Look up a ticket, then request the car for the guest.'
                : 'Look up a ticket, then validate it for your shop.'),
            style: TextStyle(fontSize: 12, color: context.vf.textSecondary),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ticketNoController,
            enabled: enabled,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              labelText: tr(context, 'Ticket Number'),
              hintText: tr(context, 'Scan or type the ticket number'),
              prefixIcon: const Icon(Icons.confirmation_number_outlined),
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => _lookup(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: enabled ? _scanTicket : null,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: Text(tr(context, 'Scan Barcode')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: enabled ? _lookup : null,
                  child: _looking
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(tr(context, 'Check')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTicketCard(MyShop shop, TicketStatusResponse v) {
    final vf = context.vf;
    final received = v.status == 'RECEIVED';
    final status = _requested ? 'REQUESTED' : (v.status ?? '');
    final bay = _nonEmpty(v.bayNo) ?? _nonEmpty(v.parkingLocation) ?? '-';
    final vehicle = [v.vehicleMake, v.vehicleColor].where((s) => s != null && s.isNotEmpty).join(' · ');

    // Capabilities (null on the server = on).
    final outletValidates = shop.canValidate;
    final outletRequests = shop.canRequest;
    final requestOnly = shop.requestOnly;

    final shopCharge = v.shopCharge;
    final chargeKnown = shopCharge != null;
    final canRequestNow = isZeroCharge(shopCharge);
    final shopName = shop.name.isNotEmpty ? shop.name : (v.shopName ?? '');
    // Validated by any outlet (this one included) and by whom.
    final validatedByAny = _validated || (v.shopValidated ?? false) || v.shopId != null;
    final validatorName = _nonEmpty(v.validatedShopName) ?? _nonEmpty(v.shopName) ?? (_validated ? shopName : '');
    // The price that applies if this login requests the car now.
    final applicable = v.applicableCharge ??
        (requestOnly ? v.parkingCharge : (_validated && chargeKnown ? shopCharge : v.parkingCharge));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: vf.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: vf.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.directions_car_rounded, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(tr(context, 'Ticket {no}', {'no': v.ticketNo}),
                    overflow: TextOverflow.ellipsis, style: AppTheme.mono(size: 16, weight: FontWeight.w700, color: vf.textPrimary)),
              ),
              _chip(_statusLabel(status), ticketStateColor(status, Theme.of(context).brightness)),
              if (received && validatedByAny) ...[
                const SizedBox(width: 6),
                _chip(tr(context, 'Shop validated'), vf.success, outlined: true),
              ],
            ],
          ),
          const SizedBox(height: 12),
          if (received && !_requested)
            validatedByAny
                ? _banner(Icons.check_circle_rounded, vf.success, vf.successSoft,
                    tr(context, 'Already validated by {shop}', {'shop': validatorName.isNotEmpty ? validatorName : tr(context, 'an outlet')}))
                : _banner(Icons.info_outline, vf.live, vf.infoSoft, tr(context, 'Not validated'))
          else if (!received)
            _banner(Icons.info_outline, vf.warning, vf.warningSoft, _progressLine(v.status),
                detail: tr(context, 'Only a parked car can be validated or requested.')),
          const SizedBox(height: 12),
          _row(tr(context, 'Plate'), v.plateNo ?? '-', mono: true),
          _row(tr(context, 'Bay'), bay),
          _row(tr(context, 'Vehicle'), vehicle.isNotEmpty ? vehicle : '-'),
          if (received) ...[
            _row(tr(context, requestOnly ? 'Guest pays at the valet desk' : 'Price that applies'), tr(context, 'AED {amount}', {'amount': shopMoney(applicable)})),
            if (outletValidates && !validatedByAny && chargeKnown)
              _row(
                  shopName.isNotEmpty
                      ? tr(context, 'After validation by {shop}', {'shop': shopName})
                      : tr(context, 'After validation by your shop'),
                  tr(context, 'AED {amount}', {'amount': shopMoney(shopCharge)})),
          ],
          if (received) ...[
            Divider(height: 28, color: vf.line),
            if (_requested)
              _banner(Icons.check_circle_rounded, vf.success, vf.successSoft,
                  tr(context, 'The car for ticket {no} has been requested. The valet team is bringing it.', {'no': v.ticketNo}))
            else
              ..._actions(
                v,
                outletValidates: outletValidates,
                outletRequests: outletRequests,
                requestOnly: requestOnly,
                validatedByAny: validatedByAny,
                chargeKnown: chargeKnown,
                canRequestNow: canRequestNow,
                applicable: applicable,
              ),
          ],
        ],
      ),
    );
  }

  // Only what this outlet can do; nothing at all when it can neither validate nor request.
  List<Widget> _actions(
    TicketStatusResponse v, {
    required bool outletValidates,
    required bool outletRequests,
    required bool requestOnly,
    required bool validatedByAny,
    required bool chargeKnown,
    required bool canRequestNow,
    required double? applicable,
  }) {
    final vf = context.vf;
    final busy = _busy != null;
    final showValidate = outletValidates && !validatedByAny;
    final caption = TextStyle(fontSize: 12, color: vf.textSecondary);
    return [
      if (_validated && outletValidates) ...[
        _banner(Icons.verified_rounded, vf.success, vf.successSoft, tr(context, 'Ticket {no} is validated for your shop.', {'no': v.ticketNo})),
        const SizedBox(height: 12),
      ],
      if (_actionError != null) ...[
        _banner(Icons.error_outline, vf.danger, vf.dangerSoft, tr(context, _actionError!)),
        const SizedBox(height: 12),
      ],
      if (outletRequests || showValidate) ...[
        TextField(
          controller: _remarksController,
          enabled: !busy,
          maxLines: 2,
          decoration: InputDecoration(labelText: tr(context, 'Remarks (optional)'), border: const OutlineInputBorder(), isDense: true),
        ),
        const SizedBox(height: 12),
      ],
      if (requestOnly) ...[
        _actionButton(
          label: _busy == _Busy.request ? 'Requesting...' : 'Request car',
          icon: Icons.directions_car_filled_rounded,
          filled: true,
          onPressed: busy ? null : _handleRequestOnly,
        ),
        const SizedBox(height: 8),
        Text(tr(context, 'Guest pays AED {amount} at the valet desk.', {'amount': shopMoney(applicable)}), style: caption),
      ] else ...[
        if (showValidate) ...[
          _actionButton(
            label: _busy == _Busy.validate ? 'Validating...' : 'Validate',
            icon: Icons.verified_outlined,
            filled: true,
            onPressed: busy ? null : _handleValidate,
          ),
          const SizedBox(height: 10),
        ],
        if (outletRequests) ...[
          _actionButton(
            label: _busy == _Busy.request ? 'Requesting...' : (_validated ? 'Request car' : 'Validate & request car'),
            icon: Icons.directions_car_filled_rounded,
            filled: _validated,
            onPressed: busy || !canRequestNow ? null : _handleValidateAndRequest,
          ),
          if (!canRequestNow) ...[
            const SizedBox(height: 8),
            Text(
              tr(context, chargeKnown
                  ? 'This ticket still has a charge with your shop - the guest pays and requests the car at the valet desk.'
                  : 'The charge with your shop is not known yet - the car can be requested at the valet desk.'),
              style: caption,
            ),
          ],
        ] else
          Text(tr(context, 'Requesting the car is done at the valet desk.'), style: caption),
      ],
    ];
  }

  Widget _actionButton({required String label, required IconData icon, required bool filled, VoidCallback? onPressed}) {
    final child = Text(tr(context, label));
    return SizedBox(
      height: 46,
      child: filled
          ? FilledButton.icon(onPressed: onPressed, icon: Icon(icon, size: 20), label: child)
          : OutlinedButton.icon(onPressed: onPressed, icon: Icon(icon, size: 20), label: child),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'RECEIVED':
        return tr(context, 'Parked');
      case 'REQUESTED':
      case 'VALIDATED':
        return tr(context, 'Requested');
      case 'ONTHEWAY':
        return tr(context, 'On the way');
      case 'ARRIVED':
        return tr(context, 'Arrived');
      case 'DELIVERED':
        return tr(context, 'Delivered');
      default:
        return status.isEmpty ? '-' : status;
    }
  }

  // Where a car that is no longer parked is now.
  String _progressLine(String? status) {
    switch (status) {
      case 'REQUESTED':
      case 'VALIDATED':
        return tr(context, 'Already requested');
      case 'ONTHEWAY':
        return tr(context, 'Already requested - the car is on the way');
      case 'ARRIVED':
        return tr(context, 'The car is at the lobby');
      case 'DELIVERED':
        return tr(context, 'Delivered');
      default:
        return tr(context, 'Ticket status: {status}', {'status': status ?? '-'});
    }
  }

  Widget _chip(String label, Color color, {bool outlined = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: outlined ? null : color,
          borderRadius: BorderRadius.circular(10),
          border: outlined ? Border.all(color: color) : null,
        ),
        child: Text(label,
            style: TextStyle(color: outlined ? color : AppTheme.contrastOn(color), fontSize: 11, fontWeight: FontWeight.w700)),
      );

  Widget _banner(IconData icon, Color color, Color fill, String text, {String? detail}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
                  if (detail != null) ...[
                    const SizedBox(height: 2),
                    Text(detail, style: TextStyle(color: context.vf.textBody, fontSize: 12.5)),
                  ],
                ],
              ),
            ),
          ],
        ),
      );

  Widget _row(String label, String value, {bool mono = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(label, style: TextStyle(fontSize: 13.5, color: context.vf.textSecondary))),
            const SizedBox(width: 12),
            Flexible(
              child: Text(value,
                  textAlign: TextAlign.end,
                  style: mono
                      ? AppTheme.mono(size: 14, weight: FontWeight.w700, color: context.vf.textPrimary)
                      : TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.vf.textPrimary)),
            ),
          ],
        ),
      );

  static String? _nonEmpty(String? s) => (s == null || s.trim().isEmpty) ? null : s;
}
