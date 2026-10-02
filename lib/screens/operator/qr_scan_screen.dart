import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../providers/operator_trip_controller.dart';
import '../../widgets/state_views.dart';

/// Scans student QR cards and posts each token to `/attendance/scan/`. The
/// backend resolves the student within the operator's own active trip and
/// school and decides whether it's a boarding or a drop.
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final _scanner = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
  bool _busy = false;
  String? _lastToken;
  DateTime? _lastAt;
  (String, bool)? _result;

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    final token = capture.barcodes.map((b) => b.rawValue).whereType<String>().firstOrNull?.trim();
    if (token == null || token.isEmpty || _busy) return;
    // The same card held in front of the camera shouldn't be re-sent every frame.
    final now = DateTime.now();
    if (token == _lastToken && _lastAt != null && now.difference(_lastAt!) < const Duration(seconds: 4)) return;
    _lastToken = token;
    _lastAt = now;

    setState(() => _busy = true);
    final result = await context.read<OperatorTripController>().scanQr(token);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _result = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan student QR'),
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: result == null
                ? Theme.of(context).colorScheme.surfaceContainerHighest
                : (result.$2 ? AppColors.red : AppColors.green).withValues(alpha: 0.12),
            child: Row(
              children: [
                if (_busy)
                  const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                else
                  Icon(
                    result == null ? Icons.qr_code_scanner : (result.$2 ? Icons.error_outline : Icons.check_circle),
                    color: result == null ? null : (result.$2 ? AppColors.red : AppColors.green),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _busy ? 'Recording…' : (result?.$1 ?? 'Point the camera at a student\'s QR card.'),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
