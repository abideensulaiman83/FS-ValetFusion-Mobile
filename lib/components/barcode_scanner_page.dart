// lib/components/barcode_scanner_page.dart
//
// Shared full-screen barcode scanner used by both the Driver and Gate Scanner flows to read the
// ticket barcode. Pops with the scanned code's raw text, or null if cancelled.
// Reads QR codes and 1D barcodes alike; torch and camera switch for dark garages / desk tablets.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../l10n/app_strings.dart';

class BarcodeScannerPage extends StatefulWidget {
  final String title;
  final String hint;

  const BarcodeScannerPage({super.key, this.title = 'Scan Ticket Barcode', this.hint = 'Point the camera at the ticket barcode'});

  @override
  State<BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<BarcodeScannerPage> {
  final MobileScannerController _controller = MobileScannerController();
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final value = barcodes.first.rawValue;
    if (value == null || value.trim().isEmpty) return;
    _handled = true;
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop(value.trim());
  }

  Widget _buildError(BuildContext context, MobileScannerException error) {
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(denied ? Icons.no_photography_outlined : Icons.error_outline, color: Colors.white70, size: 48),
          const SizedBox(height: 16),
          Text(
            tr(context, denied
                ? 'Camera access is off. Allow the camera for this app in your phone settings, then try again.'
                : 'The camera could not be started. Type the ticket number instead.'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
            child: Text(tr(context, 'Type it instead')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(tr(context, widget.title)),
        actions: [
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _controller,
            builder: (context, state, _) {
              if (!state.isInitialized || state.torchState == TorchState.unavailable) return const SizedBox.shrink();
              final on = state.torchState == TorchState.on;
              return IconButton(
                tooltip: tr(context, 'Torch'),
                icon: Icon(on ? Icons.flash_on : Icons.flash_off),
                onPressed: () => _controller.toggleTorch(),
              );
            },
          ),
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _controller,
            builder: (context, state, _) {
              if (!state.isInitialized || (state.availableCameras ?? 2) < 2) return const SizedBox.shrink();
              return IconButton(
                tooltip: tr(context, 'Switch camera'),
                icon: const Icon(Icons.cameraswitch_outlined),
                onPressed: () => _controller.switchCamera(),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect, errorBuilder: _buildError),
          // Aiming frame - detection still covers the whole view, so long barcodes read too.
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _controller,
            builder: (context, state, child) => state.error != null ? const SizedBox.shrink() : child!,
            child: IgnorePointer(
            child: Center(
              child: LayoutBuilder(builder: (context, constraints) {
                final side = (constraints.biggest.shortestSide * 0.7).clamp(200.0, 320.0);
                return Container(
                  width: side,
                  height: side,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                );
              }),
            ),
          ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              color: Colors.black54, // overlay on the camera view
              padding: const EdgeInsets.all(16),
              child: Text(
                tr(context, widget.hint),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
