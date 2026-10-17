import 'package:flutter/material.dart';
import '../main.dart';
import '../models.dart';
import '../services/files.dart';
import '../store.dart';
import 'audit.dart';

class ReportHomeScreen extends StatefulWidget {
  final RetailStore store;
  const ReportHomeScreen({super.key, required this.store});
  @override
  State<ReportHomeScreen> createState() => _ReportHomeScreenState();
}

class _ReportHomeScreenState extends State<ReportHomeScreen> {
  bool busy = false;
  Future<void> importAudit() async {
    setState(() => busy = true);
    try {
      final file = await AuditFiles.pickTable();
      if (file == null) return;
      final audit = AuditFiles.parseAudit(file);
      await widget.store.addImportedAudit(audit);
      if (!mounted) return;
      showSuccess(context, 'Uploaded audit saved: ${audit.name}');
    } catch (e) { showFailure(context, e); }
    finally { if (mounted) setState(() => busy = false); }
  }
  Future<void> importSoh() async {
    setState(() => busy = true);
    try {
      final file = await AuditFiles.pickTable();
      if (file == null) return;
      await widget.store.setSoh(AuditFiles.parseSoh(file), file.name);
      if (mounted) showSuccess(context, 'SOH uploaded');
    } catch (e) { showFailure(context, e); }
    finally { if (mounted) setState(() => busy = false); }
  }
  @override
  Widget build(BuildContext context) => DefaultTabController(length: 3,
    child: Scaffold(appBar: AppBar(title: const Text('View Report'), bottom: const TabBar(
      tabs: [Tab(text: 'Audit Reports'), Tab(text: 'SOH'), Tab(text: 'Variance')])),
      body: TabBarView(children: [
        ListView(padding: const EdgeInsets.all(16), children: [
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
            children: [const Text('Saved audits and imported external audit reports appear below.'),
              const SizedBox(height: 12),
              actionButton(busy ? 'Uploading…' : 'Upload Audit Report',
                busy ? () {} : importAudit, icon: Icons.upload_file)]))),
          const SizedBox(height: 12),
          Text('Saved Audit Reports (${widget.store.reports.length})',
            style: Theme.of(context).textTheme.titleLarge),
          if (widget.store.reports.isEmpty) emptyView('No audits saved yet.'),
          ...widget.store.reports.map((a) => Card(child: ListTile(
            title: Text(a.name),
            subtitle: Text('${a.brand} · ${a.storeCode} · ${a.racks.length} racks · ${a.units} units\n${a.imported ? 'Uploaded report' : 'Saved in app'}'),
            isThreeLine: true,
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => AuditReportDetailScreen(store: widget.store, audit: a))))))
        ]),
        ListView(padding: const EdgeInsets.all(16), children: [
          const Text('SOH — Stock On Hand'),
          const SizedBox(height: 8),
          Text(widget.store.soh.isEmpty ? 'No SOH saved yet' :
            '${widget.store.sohFileName} · ${widget.store.soh.length} products'),
          const SizedBox(height: 10),
          actionButton(widget.store.soh.isEmpty ? 'Upload SOH File' : 'Replace SOH File',
            importSoh, icon: Icons.file_upload_outlined),
          if (widget.store.soh.isNotEmpty) ...[
            const SizedBox(height: 10),
            actionButton('Export SOH Excel', () async {
              try { await AuditFiles.shareFile(await AuditFiles.sohExcel(widget.store)); }
              catch (e) { showFailure(context, e); }
            }, icon: Icons.file_download_outlined),
          ],
          ...widget.store.soh.take(200).map((r) => Card(child: ListTile(
            title: Text(r.barcode), trailing: Text('SOH ${r.stock}')))),
        ]),
        ListView(padding: const EdgeInsets.all(16), children: [
          actionButton('Generate Variance Report', () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => VarianceGeneratorScreen(store: widget.store))),
            icon: Icons.analytics),
          const SizedBox(height: 10),
          if (widget.store.varianceReports.isEmpty) emptyView('No variance reports generated.'),
          ...widget.store.varianceReports.map((r) => Card(child: ListTile(
            title: Text(r.name), subtitle: Text('${r.date} · ${r.mismatchCount} differences'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => VarianceDetailScreen(store: widget.store, report: r))))))
        ]),
      ])));
}

class AuditReportDetailScreen extends StatefulWidget {
  final RetailStore store;
  final Audit audit;
  const AuditReportDetailScreen({super.key, required this.store, required this.audit});
  @override
  State<AuditReportDetailScreen> createState() => _AuditReportDetailScreenState();
}

class _AuditReportDetailScreenState extends State<AuditReportDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final a = widget.audit;
    return Scaffold(appBar: AppBar(title: Text(a.name)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a.name, style: Theme.of(context).textTheme.titleLarge),
            Text('Company / Brand: ${a.brand}'),
            Text('Store: ${a.storeCode}'),
            Text('Date: ${a.date} · Expected EAN: ${a.eanLength}'),
            Text('${a.racks.length} rack(s) · ${a.units} units'),
          ]))),
        actionButton('Share / Download Audit Excel', () async {
          try { await AuditFiles.shareFile(await AuditFiles.auditExcel(a)); }
          catch (e) { showFailure(context, e); }
        }, icon: Icons.file_download_outlined),
        const SizedBox(height: 15),
        Text('Select Rack to View or Edit', style: Theme.of(context).textTheme.titleMedium),
        ...List.generate(a.racks.length, (i) {
          final r = a.racks[i];
          return Card(child: ListTile(
            title: Text(r.rack),
            subtitle: Text('Auditor: ${r.auditor} · ${r.rows.length} products · ${r.units} units'),
            trailing: const Icon(Icons.edit_outlined),
            onTap: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) =>
                ActiveAuditScreen(store: widget.store, existingReport: a, initialRack: i)));
              if (mounted) setState(() {});
            }));
        }),
        const SizedBox(height: 8),
        const Text('Saved edits are local until cloud sync and email are configured.',
          style: TextStyle(fontSize: 12)),
      ]));
  }
}

class VarianceGeneratorScreen extends StatefulWidget {
  final RetailStore store;
  const VarianceGeneratorScreen({super.key, required this.store});
  @override
  State<VarianceGeneratorScreen> createState() => _VarianceGeneratorScreenState();
}

class _VarianceGeneratorScreenState extends State<VarianceGeneratorScreen> {
  String? selectedAuditId;
  bool working = false;
  Future<void> make() async {
    final matching = widget.store.reports.where((a) => a.id == selectedAuditId);
    if (matching.isEmpty) { showFailure(context, 'Select an audit first'); return; }
    if (widget.store.soh.isEmpty) { showFailure(context, 'Upload SOH first'); return; }
    setState(() => working = true);
    try {
      final report = await widget.store.makeVariance(matching.first);
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) =>
        VarianceDetailScreen(store: widget.store, report: report)));
    } catch (e) { showFailure(context, e); }
    finally { if (mounted) setState(() => working = false); }
  }
  Future<void> importSoh() async {
    try {
      final file = await AuditFiles.pickTable();
      if (file == null) return;
      await widget.store.setSoh(AuditFiles.parseSoh(file), file.name);
      if (mounted) setState(() {});
    } catch (e) { showFailure(context, e); }
  }
  Future<void> importAudit() async {
    try {
      final file = await AuditFiles.pickTable();
      if (file == null) return;
      final audit = AuditFiles.parseAudit(file);
      await widget.store.addImportedAudit(audit);
      if (mounted) setState(() => selectedAuditId = audit.id);
    } catch (e) { showFailure(context, e); }
  }
  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    return Scaffold(appBar: AppBar(title: const Text('Variance Report')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Step 1: Choose Saved Audit',
              style: TextStyle(fontWeight: FontWeight.w800)),
            if (s.reports.isNotEmpty) DropdownButtonFormField<String>(
              value: s.reports.any((a) => a.id == selectedAuditId) ? selectedAuditId : null,
              hint: const Text('Select audit'),
              items: s.reports.map((a) => DropdownMenuItem(
                value: a.id, child: Text(a.name))).toList(),
              onChanged: (v) => setState(() => selectedAuditId = v)),
            if (s.reports.isEmpty) const Text('No saved audits yet.'),
            TextButton.icon(onPressed: importAudit, icon: const Icon(Icons.upload_file),
              label: const Text('Or upload an audit from another device')),
          ]))),
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Step 2: Choose SOH',
              style: TextStyle(fontWeight: FontWeight.w800)),
            Text(s.soh.isEmpty ? 'No SOH saved' :
              '${s.sohFileName} · ${s.soh.length} products'),
            TextButton.icon(onPressed: importSoh, icon: const Icon(Icons.upload_file),
              label: Text(s.soh.isEmpty ? 'Upload SOH' : 'Replace SOH')),
          ]))),
        const SizedBox(height: 15),
        actionButton(working ? 'Generating…' : 'Generate Variance Report',
          working ? () {} : make, icon: Icons.analytics),
        const SizedBox(height: 12),
        const Text('Difference = Physical Count − SOH. Counts are aggregated by barcode '
          'across racks only for this variance report.', style: TextStyle(fontSize: 12)),
      ]));
  }
}

class VarianceDetailScreen extends StatelessWidget {
  final RetailStore store;
  final VarianceReport report;
  const VarianceDetailScreen({super.key, required this.store, required this.report});
  @override
  Widget build(BuildContext context) {
    final audits = store.reports.where((a) => a.id == report.auditId);
    return Scaffold(appBar: AppBar(title: const Text('Variance Report')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(report.name, style: Theme.of(context).textTheme.titleLarge),
        Text('${report.lines.length} barcodes · ${report.mismatchCount} variances'),
        const SizedBox(height: 14),
        actionButton('Share / Download Variance Excel', () async {
          try { await AuditFiles.shareFile(await AuditFiles.varianceExcel(report)); }
          catch (e) { showFailure(context, e); }
        }, icon: Icons.download),
        const SizedBox(height: 10),
        if (audits.isNotEmpty && store.soh.isNotEmpty)
          actionButton('Share All Three Excel Reports', () async {
            try { await AuditFiles.shareAllThree(
              audit: audits.first, store: store, variance: report); }
            catch (e) { showFailure(context, e); }
          }, icon: Icons.attach_email),
        const SizedBox(height: 7),
        const Text('This opens your phone’s share/email sheet. Automatic Gmail '
          'delivery requires the production backend.', style: TextStyle(fontSize: 12)),
        const SizedBox(height: 12),
        ...report.lines.map((line) => Card(child: ListTile(
          title: Text(line.barcode), subtitle: Text('SOH ${line.soh}  |  Physical ${line.physical}'),
          trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(line.difference > 0 ? '+${line.difference}' : '${line.difference}',
              style: TextStyle(fontWeight: FontWeight.bold,
                color: line.difference == 0 ? Colors.green : Colors.deepOrange)),
            Text(line.status, style: const TextStyle(fontSize: 11)),
          ])))),
      ]));
  }
}

class DeleteScreen extends StatefulWidget {
  final RetailStore store;
  const DeleteScreen({super.key, required this.store});
  @override
  State<DeleteScreen> createState() => _DeleteScreenState();
}

class _DeleteScreenState extends State<DeleteScreen> {
  String category = 'audits';
  String? selected;
  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    final items = <(String, String)>[
      if (category == 'audits') ...s.reports.map((a) => (a.id, a.name)),
      if (category == 'variance') ...s.varianceReports.map((r) => (r.id, r.name)),
      if (category == 'soh' && s.soh.isNotEmpty) ('soh', s.sohFileName),
      if (category == 'locations' && s.locationBarcodes.isNotEmpty)
        ('locations', s.locationFileNames.isNotEmpty ? s.locationFileNames.first : 'Location Barcodes'),
    ];
    return Scaffold(appBar: AppBar(title: const Text('Clear Data')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Choose exactly which saved file to delete. No Delete All Data option.'),
        const SizedBox(height: 15),
        DropdownButtonFormField<String>(value: category,
          decoration: const InputDecoration(labelText: 'File Type'),
          items: const [
            DropdownMenuItem(value: 'audits', child: Text('Audit Reports')),
            DropdownMenuItem(value: 'variance', child: Text('Variance Reports')),
            DropdownMenuItem(value: 'soh', child: Text('SOH File')),
            DropdownMenuItem(value: 'locations', child: Text('Location Barcode File')),
          ],
          onChanged: (v) => setState(() { category = v ?? 'audits'; selected = null; })),
        const SizedBox(height: 15),
        if (items.isEmpty) emptyView('No saved files in this category.'),
        ...items.map((item) => RadioListTile<String>(
          title: Text(item.$2), value: item.$1, groupValue: selected,
          onChanged: (v) => setState(() => selected = v))),
        if (items.isNotEmpty) actionButton('Delete Selected File', () async {
          if (selected == null) { showFailure(context, 'Select a file'); return; }
          final confirmed = await confirmAction(context, 'Delete selected file?',
            'Only the selected file will be deleted. This cannot be undone without a backup.',
            confirmText: 'Delete');
          if (!confirmed || !context.mounted) return;
          try {
            switch (category) {
              case 'audits': await s.deleteReport(selected!); break;
              case 'variance': await s.deleteVariance(selected!); break;
              case 'soh': await s.deleteSoh(); break;
              case 'locations': await s.deleteLocationList(); break;
            }
            if (mounted) setState(() => selected = null);
            if (context.mounted) showSuccess(context, 'Selected file deleted.');
          } catch (e) { showFailure(context, e); }
        }, icon: Icons.delete_forever),
      ]));
  }
}
