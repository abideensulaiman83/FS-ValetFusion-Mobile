// lib/components/guest_tracking_qr_sheet.dart
//
// Shown to the guest right after their car is received: they scan it with the phone camera and
// land on the public /track/<CODE>/<TICKET> page (the web app) with that car's live status and
// ETA - no app, no login, nothing to type. The same page also works from the property QR printed
// on tickets, where the guest types the ticket number instead.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/authentication_service.dart';
import '../services/valet_service.dart';

class GuestTrackingQr {
  /// Public tracking link for one ticket, e.g. https://valetfusion.focalsoft.ae/track/TYU/0028.
  static String urlFor(String companyCode, String ticketNo) {
    final origin = AuthenticationService.apiBaseUrl.replaceFirst(
      RegExp(r'/api/?$'),
      '',
    );
    return '$origin/track/${Uri.encodeComponent(companyCode)}/${Uri.encodeComponent(ticketNo)}';
  }

  /// Opens the QR sheet for [ticketNo]. Silently does nothing if the company code can't be
  /// fetched - the receive itself already succeeded, so this must never surface as an error.
  static Future<void> show(
    BuildContext context, {
    required String ticketNo,
    String? vehicleText,
  }) async {
    // Fetched each time rather than cached: the user may have switched location or re-logged in
    // to another company since the last receive.
    final TrackingCompany company;
    try {
      company = await ValetService().fetchTrackingCompany();
    } catch (_) {
      return;
    }
    if (!context.mounted) return;
    final url = urlFor(company.code, ticketNo);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Ticket $ticketNo',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (vehicleText != null && vehicleText.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  vehicleText,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                'Ask the guest to scan this to follow their car',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: QrImageView(
                  data: url,
                  size: 240,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              SelectableText(
                url,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: url));
                        if (sheetContext.mounted) {
                          ScaffoldMessenger.of(sheetContext).showSnackBar(
                            const SnackBar(content: Text('Link copied')),
                          );
                        }
                      },
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('Copy link'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      child: const Text('Done'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
