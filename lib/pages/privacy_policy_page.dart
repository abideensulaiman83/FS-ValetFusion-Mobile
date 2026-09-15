// lib/pages/privacy_policy_page.dart
//
// Static privacy policy / terms screen, reachable from the landing page - written for
// ValetFusion's own data handling (ticket/vehicle records, guest mobile numbers, live GPS while
// a driver is bringing a car back), not copied from a generic template.
import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy & Policy')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Valet Fusion - Privacy Policy', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('Last updated: September 2026', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              const SizedBox(height: 20),
              _section(
                'What we collect',
                'When you use Valet Fusion at a participating property, we collect: your mobile '
                    'number and name (for a guest account), your vehicle\'s plate number, color and '
                    'make/model (captured by the parking attendant, sometimes assisted by an '
                    'automatic plate-recognition camera), your ticket number, and - only while your '
                    'car is actively being brought to you - the driver\'s live GPS location, so you '
                    'can see it on a map and get an estimated arrival time.',
              ),
              _section(
                'How we use it',
                'Your details are used only to run the valet service you\'re actively using: '
                    'matching your ticket to your car, notifying the team when you request pickup, '
                    'and giving you live status. We do not sell your data, and we do not use it for '
                    'advertising.',
              ),
              _section(
                'Who can see it',
                'Only staff at the specific property you\'re parked at (drivers, lobby desk, key '
                    'controllers, and that property\'s admins) can see your ticket, vehicle, and '
                    'contact details. A live GPS location is visible only to you and that property\'s '
                    'staff while a car is on its way, and is not retained once delivered.',
              ),
              _section(
                'Complaints & feedback',
                'If you submit feedback or a complaint, it is stored against the property you '
                    'reported it to, along with the mobile number you provided, so you can check back '
                    'on it later using your reference number. It is visible to that property\'s admins '
                    'only.',
              ),
              _section(
                'How long we keep it',
                'Ticket and vehicle records are retained for the property\'s normal operational and '
                    'audit purposes. Live GPS location data is not stored beyond the delivery it was '
                    'collected for.',
              ),
              _section(
                'Your choices',
                'You can stop using the app at any time; this does not delete historical ticket '
                    'records the property is required to keep for its own operations. For a specific '
                    'data request, contact the property directly - they control your data as the '
                    'operator of the service you used.',
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)),
                child: const Text(
                  'This app is provided by Integrated Parking Solution '
                  '(www.integeratedparkingsolution.com/ae) to its client properties. Each property '
                  'is responsible for its own guests\' data as the operator of the valet service.',
                  style: TextStyle(fontSize: 12.5, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(body, style: const TextStyle(fontSize: 13.5, height: 1.5)),
        ],
      ),
    );
  }
}
