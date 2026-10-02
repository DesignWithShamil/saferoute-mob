import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../widgets/state_views.dart';

/// Reads a QR value and pops it. Does not post attendance — used by
/// driver/helper student lookup the same way React `/driver/lookup` does.
class QrCaptureScreen extends StatefulWidget {
  const QrCaptureScreen({super.key, this.title = 'Scan student QR'});
  final String title;

  @override
  State<QrCaptureScreen> createState() => _QrCaptureScreenState();
}

class _QrCaptureScreenState extends State<QrCaptureScreen> {
  final _scanner = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
  bool _done = false;

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    final token = capture.barcodes.map((b) => b.rawValue).whereType<String>().firstOrNull?.trim();
    if (token == null || token.isEmpty) return;
    _done = true;
    Navigator.of(context).pop(token);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          actions: [
            IconButton(icon: const Icon(Icons.flash_on), tooltip: 'Torch', onPressed: () => _scanner.toggleTorch()),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: MobileScanner(
                controller: _scanner,
                onDetect: _onDetect,
                errorBuilder: (context, error) => ErrorView(
                  message: error.errorCode == MobileScannerErrorCode.permissionDenied
                      ? 'Camera permission is needed to scan student QR cards. Enable it in app settings.'
                      : 'Camera unavailable: ${error.errorDetails?.message ?? error.errorCode.name}',
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Point the camera at a student\'s QR card.'),
            ),
          ],
        ),
      );
}
