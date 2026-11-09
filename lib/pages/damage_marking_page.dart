// lib/pages/damage_marking_page.dart
//
// Desk-side damage marking for a car that is already received/parked: the key controller opens
// it from the request dialog or a row of the Received vehicles list and gets the
// same editor the driver has at check-in (DamageMarkingCard - same /v1/vehicle-damages API).
// Marks already on the ticket load first and stay read-only. Premium (DAMAGE_MARKING): the card
// itself shows the "Part of Premium" state on a Free plan.
// Client rule: damage marking is the Key Controller's (control desk) job, not the Lobby user's -
// see canMarkDeskDamage(); the backend refuses vehicle-damage writes from LOBBY as well.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../components/damage/damage_marking_card.dart';
import '../components/premium.dart';
import '../l10n/app_strings.dart';
import '../services/authentication_service.dart';
import '../services/plan_service.dart';

/// Whether the given roles may mark damage from the desk: Key Controller, admins and valet
/// staff/drivers yes; a Lobby-only user no.
bool rolesCanMarkDamage(List<String> roles) => !roles.contains('LOBBY') || roles.contains('KEY_CONTROLLER');

/// Reads the signed-in user's roles and applies [rolesCanMarkDamage]. False when unreadable.
Future<bool> canMarkDeskDamage() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString(AuthenticationService.userKey);
    if (userStr == null) return false;
    final roles = List<String>.from((jsonDecode(userStr) as Map<String, dynamic>)['roles'] ?? const []);
    return rolesCanMarkDamage(roles);
  } catch (_) {
    return false;
  }
}

/// Opens the damage marking editor for one received car.
Future<void> openDamageMarking(BuildContext context, {required int parkingVehicleId, required String ticketNo, String? subtitle}) {
  return Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => DamageMarkingPage(parkingVehicleId: parkingVehicleId, ticketNo: ticketNo, subtitle: subtitle),
  ));
}

/// Small button for the desk's request dialog: "Damage marking".
class DamageMarkingButton extends StatelessWidget {
  final int? parkingVehicleId;
  final String ticketNo;
  final String? subtitle;
  const DamageMarkingButton({super.key, required this.parkingVehicleId, required this.ticketNo, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final id = parkingVehicleId;
    if (id == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: OutlinedButton.icon(
        onPressed: () => openDamageMarking(context, parkingVehicleId: id, ticketNo: ticketNo, subtitle: subtitle),
        icon: const Icon(Icons.car_crash_outlined, size: 18),
        label: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(tr(context, 'Damage marking')),
          const SizedBox(width: 6),
          const PremiumStar(featureKey: PremiumFeature.damageMarking, size: 14),
        ]),
      ),
    );
  }
}

class DamageMarkingPage extends StatelessWidget {
  final int parkingVehicleId;
  final String ticketNo;
  final String? subtitle;
  const DamageMarkingPage({super.key, required this.parkingVehicleId, required this.ticketNo, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sub = subtitle == null || subtitle!.isEmpty ? '' : ' · $subtitle';
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(tr(context, 'Damage marking')),
          Text('${tr(context, 'Ticket {no}', {'no': ticketNo})}$sub', style: theme.textTheme.bodySmall?.copyWith(fontSize: 11.5)),
        ]),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [DamageMarkingCard(parkingVehicleId: parkingVehicleId)],
        ),
      ),
    );
  }
}
