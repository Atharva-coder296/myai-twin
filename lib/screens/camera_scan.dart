import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Returns one decoded barcode to the caller. The audit screen applies the
/// same validation, rack assignment and quantity logic as HHT input.
class CameraScanScreen extends StatefulWidget {
  const CameraScanScreen({super.key});
  @override
  State<CameraScanScreen> createState() => _CameraScanScreenState();
}
class _CameraScanScreenState extends State<CameraScanScreen> {
  bool completed = false;
  String? cameraError;
  final controller = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
  @override
  void dispose() { controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Scan with Camera')),
    body: cameraError != null
      ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(
          'Camera unavailable: $cameraError\nYou can still use an HHT, USB/Bluetooth scanner, or manual entry.',
          textAlign: TextAlign.center)))
      : MobileScanner(controller: controller, onDetect: (capture) {
      if (completed || capture.barcodes.isEmpty) return;
      final value = capture.barcodes.first.rawValue?.trim();
      if (value == null || value.isEmpty) return;
      completed = true;
      Navigator.of(context).pop(value);
    }),
  );
}
