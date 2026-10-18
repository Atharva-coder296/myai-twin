import 'package:flutter/material.dart';
import '../main.dart';
import '../services/files.dart';
import '../store.dart';
import 'audit.dart';
import 'employee_registration.dart';

class UploadScreen extends StatelessWidget {
  final RetailStore store;
  const UploadScreen({super.key, required this.store});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Upload Data')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      if (store.isAdmin) _tile(context, 'Add User', Icons.person_add_alt_1,
        'Register an employee', const EmployeeRegistrationScreen()),
      _tile(context, 'Upload Barcode File', Icons.view_list_outlined,
        'Import rack/location barcodes', UploadLocationScreen(store: store)),
      _tile(context, 'Upload Product Barcode', Icons.inventory_outlined,
        'Barcode scanner and SOH Excel file', UploadProductScreen(store: store)),
    ]),
  );
}

Widget _tile(BuildContext context, String title, IconData icon, String subtitle, Widget page) =>
    Card(child: ListTile(leading: Icon(icon, size: 29), title: Text(title),
      subtitle: Text(subtitle), trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page))));

class UploadLocationScreen extends StatefulWidget {
  final RetailStore store;
  const UploadLocationScreen({super.key, required this.store});
  @override
  State<UploadLocationScreen> createState() => _UploadLocationScreenState();
}

class _UploadLocationScreenState extends State<UploadLocationScreen> {
  bool busy = false;
  Future<void> upload() async {
    setState(() => busy = true);
    try {
      final file = await AuditFiles.pickTable();
      if (file == null) return;
      final locations = AuditFiles.parseLocations(file);
      await widget.store.setLocationBarcodes(locations, file.name);
      if (mounted) showSuccess(context, '${locations.length} location codes imported.');
    } catch (e) { showFailure(context, e); }
    finally { if (mounted) setState(() => busy = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Upload Barcode File')),
    body: ListView(padding: const EdgeInsets.all(18), children: [
      const Text('Import the rack/location barcode list from CSV or XLSX.'),
      const SizedBox(height: 15),
      actionButton(busy ? 'Importing…' : 'Choose Location Barcode File', busy ? () {} : upload,
        icon: Icons.upload_file),
      const SizedBox(height: 15),
      Text('Current file: ${widget.store.locationFileNames.isEmpty ? 'None' : widget.store.locationFileNames.first}'),
      Text('Imported locations: ${widget.store.locationBarcodes.length}'),
      ...widget.store.locationBarcodes.take(100).map((s) => ListTile(
        leading: const Icon(Icons.location_on_outlined), title: Text(s))),
    ]),
  );
}

class UploadProductScreen extends StatefulWidget {
  final RetailStore store;
  const UploadProductScreen({super.key, required this.store});
  @override
  State<UploadProductScreen> createState() => _UploadProductScreenState();
}

class _UploadProductScreenState extends State<UploadProductScreen> {
  bool busy = false;
  Future<void> upload() async {
    setState(() => busy = true);
    try {
      final file = await AuditFiles.pickTable();
      if (file == null) return;
      final rows = AuditFiles.parseSoh(file);
      await widget.store.setSoh(rows, file.name);
      if (mounted) showSuccess(context, 'Saved ${rows.length} SOH product rows');
    } catch (e) { showFailure(context, e); }
    finally { if (mounted) setState(() => busy = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Upload Product Barcode')),
    body: ListView(padding: const EdgeInsets.all(18), children: [
      Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Barcode Scanner', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 7),
          const Text('Ready for your USB/Bluetooth 2D scanner. '
            'Both barcodes and numeric product QR codes are handled on one scanning screen.'),
          const SizedBox(height: 14),
          actionButton('READY — Start Scanning', () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => AuditEntryScreen(store: widget.store))),
            icon: Icons.qr_code_scanner),
        ]))),
      Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('SOH — Stock On Hand',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text(widget.store.soh.isEmpty ? 'No SOH uploaded yet' :
            '${widget.store.sohFileName} · ${widget.store.soh.length} products'),
          const SizedBox(height: 14),
          actionButton(busy ? 'Uploading…' : widget.store.soh.isEmpty ?
            'Choose SOH Excel / CSV File' : 'Replace SOH File', busy ? () {} : upload,
            icon: Icons.file_upload_outlined),
        ]))),
    ]),
  );
}
