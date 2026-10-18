import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../main.dart';
import '../services/files.dart';
import '../store.dart';
import 'reports.dart';
import 'audit.dart';
import 'employee_registration.dart';

class SettingsScreen extends StatelessWidget {
  final RetailStore store;
  const SettingsScreen({super.key, required this.store});

  Widget group(BuildContext context, String title, IconData icon, Widget child) =>
    Card(child: ExpansionTile(leading: Icon(icon), title: Text(title,
      style: const TextStyle(fontWeight: FontWeight.w700)), childrenPadding: const EdgeInsets.all(14),
      children: [child]));

  Widget information(String title, String subtitle, VoidCallback tap) => ListTile(
    title: Text(title), subtitle: Text(subtitle), trailing: const Icon(Icons.chevron_right),
    onTap: tap);

  void notice(BuildContext context, String title, String content) => showDialog<void>(
    context: context, builder: (dialogContext) => AlertDialog(title: Text(title),
      content: SingleChildScrollView(child: Text(content)),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext),
        child: const Text('Close'))]));

  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Settings')),
    body: ListView(padding: const EdgeInsets.all(14), children: [
      group(context, 'Account Settings', Icons.person_outline, Column(children: [
        information('Account Profile', 'View signed-in user and role', () => notice(context,
          'Account Profile', 'Name: ${store.currentUser?.name}\n'
          'User ID: ${store.currentUser?.id}\n'
          'Email: ${store.currentUser?.email}\n'
          'Role: ${store.currentUser?.role}\n'
          'Mode: local prototype; no online identity validation.')),
        information('Logout', 'Sign out of this device', () {
          Navigator.of(context).popUntil((route) => route.isFirst);
          store.signOut();
        }),
      ])),
      group(context, 'Barcode Scanner Settings', Icons.qr_code_scanner, Column(children: [
        SwitchListTile(title: const Text('Successful scan sound'), value: store.successSound,
          onChanged: (v) => store.updatePreferences(successSound: v)),
        SwitchListTile(title: const Text('Triple EAN mismatch alert'), value: store.mismatchSound,
          onChanged: (v) => store.updatePreferences(mismatchSound: v)),
        SwitchListTile(title: const Text('Vibration preference'), subtitle: const Text('Device dependent'),
          value: store.vibration, onChanged: (v) => store.updatePreferences(vibration: v)),
        information('Test Barcode Scanner', 'Live numeric / QR value input', () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const ScannerTestScreen()))),
        information('Scanner Input Diagnostics', 'Inspect lengths, time and captured values',
          () => Navigator.push(context, MaterialPageRoute(builder: (_) =>
            const ScannerTestScreen(diagnostics: true)))),
      ])),
      group(context, 'Audit Settings', Icons.playlist_add_check, Column(children: [
        const ListTile(title: Text('Auto-save after each scan'),
          subtitle: Text('Always enabled to protect inventory data'), trailing: Icon(Icons.check_circle)),
        SwitchListTile(title: const Text('Confirm before ending audit'), value: store.confirmEnd,
          onChanged: (v) => store.updatePreferences(confirmEnd: v)),
        information('Resume Unfinished Audit',
          store.draft == null ? 'No unfinished audit' :
            '${store.draft!.brand} · ${store.draft!.racks.length} rack(s)',
          () => Navigator.push(context, MaterialPageRoute(builder: (_) =>
            store.draft == null ? AuditEntryScreen(store: store) :
              ActiveAuditScreen(store: store)))),
      ])),
      group(context, 'Reports & Export', Icons.file_download_outlined, Column(children: [
        information('Report Generation History',
          '${store.reports.length} audits · ${store.varianceReports.length} variance reports',
          () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => ReportHomeScreen(store: store)))),
        const ListTile(title: Text('Report Format'),
          subtitle: Text('XLSX Excel with location-wise audit rows')),
        const ListTile(title: Text('Variance Formula'),
          subtitle: Text('Physical count − SOH, aggregated across racks')),
      ])),
      group(context, 'Notifications', Icons.notifications_outlined, Column(children: [
        information('Email Delivery Status', 'Email service not connected',
          () => notice(context, 'Email Delivery',
            'Report sender: retailsaudit@gmail.com\n'
            'Report recipient: ${store.adminEmail}\n\n'
            'Automatic Gmail delivery is NOT active. You can share all three '
            'Excel files manually from a Variance Report. '
            'Production requires a server-side email provider and approved credentials.')),
        information('Pending Report Notifications', 'Cloud delivery queue not connected',
          () => notice(context, 'Notifications',
            'Offline reports remain saved on this device. '
            'An online notification queue will require the production backend.')),
      ])),
      group(context, 'Storage & Backup', Icons.backup_outlined, Column(children: [
        information('Browser / App Storage Usage',
          '${(utf8.encode(jsonEncode(store.snapshot())).length / 1024).toStringAsFixed(1)} KB of locally stored data',
          () => notice(context, 'Local Storage',
            'Reports: ${store.reports.length}\nVariance: ${store.varianceReports.length}\n'
            'SOH: ${store.soh.length}\nLocation codes: ${store.locationBarcodes.length}\n'
            'Draft: ${store.draft == null ? 'None' : 'Saved'}\n\n'
            'This is an approximate JSON data size, not the device’s total disk usage.')),
        information('Last Successful Sync', 'Never — cloud not connected',
          () => notice(context, 'Cloud Sync', 'No cloud server is connected yet. '
            'This app currently saves data on this device only.')),
        information('Retry Pending Uploads', 'No cloud upload queue exists yet',
          () => notice(context, 'Pending Uploads',
            'No queued server uploads can be retried. Local data is intact.')),
        information('Backup Status', 'Export or restore local data',
          () => Navigator.push(context, MaterialPageRoute(builder: (_) =>
            BackupScreen(store: store)))),
      ])),
      group(context, 'Appearance', Icons.palette_outlined, Column(children: [
        SwitchListTile(title: const Text('Dark Mode'), value: store.darkMode,
          onChanged: (v) => store.updatePreferences(darkMode: v)),
        SwitchListTile(title: const Text('High Contrast'), value: store.highContrast,
          onChanged: (v) => store.updatePreferences(highContrast: v)),
        ListTile(title: const Text('Text Size'),
          subtitle: Slider(value: store.textScale, min: 0.85, max: 1.35, divisions: 10,
            label: '${(store.textScale * 100).round()}%',
            onChanged: (v) => store.updatePreferences(textScale: v))),
      ])),
      if (store.isAdmin) group(context, 'Admin Controls', Icons.admin_panel_settings_outlined,
        Column(children: [
          information('Add User', 'Register a new employee',
            () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => const EmployeeRegistrationScreen()))),
          information('Primary Admin ID', RetailStore.primaryAdminId,
            () => notice(context, 'Primary Admin',
              'ID: RetailSAudit\nEmail: retailsaudit@gmail.com\n'
              'Password is set during initial setup and is never stored in source code.')),
          const Text('Report recipient address', style: TextStyle(fontWeight: FontWeight.bold)),
          _EmailSetting(store: store, support: false),
          const SizedBox(height: 8),
          const Text('Support address', style: TextStyle(fontWeight: FontWeight.bold)),
          _EmailSetting(store: store, support: true),
          information('Permissions', 'Admins manage accounts; employees do not',
            () => notice(context, 'Role Permissions',
              'Admin-only interface rules exist locally. '
              'Production requires backend-enforced authorization.')),
          information('Audit Edit History', 'Not yet server-audited',
            () => notice(context, 'Audit History',
              'Saved audit edits change the local report. '
              'A tamper-resistant edit history will require the production backend.')),
        ])),
      group(context, 'About RetailSAudit', Icons.info_outline, Column(children: [
        information('App Version', 'RetailSAudit Flutter v0.1.0 (MVP)',
          () => notice(context, 'App Version', 'RetailSAudit 0.1.0+1\n'
            'Flutter Android + iOS source project.')),
        information('Company Information', 'The Retail Audit & Allied Services',
          () => notice(context, 'Company Information',
            'The Retail Audit & Allied Services\n'
            'Retail inventory counts, location audits and stock variances.')),
        information('Support Contact', store.supportEmail.isEmpty ?
          'Not configured' : store.supportEmail,
          () => notice(context, 'Support Contact',
            store.supportEmail.isEmpty ? 'Ask an admin to configure support email.' :
              'Support email: ${store.supportEmail}')),
        information('Privacy and Data Policy', 'Data storage and privacy information',
          () => notice(context, 'Privacy & Data',
            'LOCAL MVP: This device stores scans, audit reports, SOH, '
            'and local demonstration account profiles. There is no remote server '
            'and no automatic email sending. SharedPreferences is not appropriate '
            'for production-grade private customer data or multi-device permissions. '
            'Secure cloud authentication, storage rules, consent, retention, and '
            'a published privacy policy must be implemented before commercial use.')),
      ])),
      const Padding(padding: EdgeInsets.all(14), child: Text(
        'This is a functional local MVP, not a production-connected company system.',
        textAlign: TextAlign.center, style: TextStyle(fontSize: 12))),
    ]));
}

class _EmailSetting extends StatefulWidget {
  final RetailStore store;
  final bool support;
  const _EmailSetting({required this.store, required this.support});
  @override
  State<_EmailSetting> createState() => _EmailSettingState();
}

class _EmailSettingState extends State<_EmailSetting> {
  late final TextEditingController controller;
  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.support ?
      widget.store.supportEmail : widget.store.adminEmail);
  }
  @override
  void dispose() { controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(child: TextField(controller: controller,
      keyboardType: TextInputType.emailAddress,
      decoration: const InputDecoration(hintText: 'name@example.com'))),
    const SizedBox(width: 8),
    IconButton(tooltip: 'Save address', onPressed: () async {
      if (!controller.text.contains('@')) { showFailure(context, 'Enter a valid email'); return; }
      if (widget.support) {
        await widget.store.updatePreferences(supportEmail: controller.text.trim());
      } else {
        await widget.store.updatePreferences(adminEmail: controller.text.trim());
      }
      if (context.mounted) showSuccess(context, 'Address saved locally. Emails are not enabled.');
    }, icon: const Icon(Icons.save_outlined)),
  ]);
}

class BackupScreen extends StatelessWidget {
  final RetailStore store;
  const BackupScreen({super.key, required this.store});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Storage & Backup')),
    body: ListView(padding: const EdgeInsets.all(18), children: [
      const Text('Save a local JSON backup using the phone’s sharing options. '
        'Backups exclude passwords and account credentials.'),
      const SizedBox(height: 14),
      actionButton('Export Local Backup', () async {
        try { await AuditFiles.shareBackup(store); }
        catch (e) { showFailure(context, e); }
      }, icon: Icons.download),
      const SizedBox(height: 14),
      if (store.isAdmin) actionButton('Restore Local Reports & SOH', () async {
        try {
          final backup = await AuditFiles.pickBackup();
          if (backup == null || !context.mounted) return;
          final confirmed = await confirmAction(context, 'Restore local backup?',
            'Existing local reports, SOH and draft will be replaced. '
            'Existing accounts and passwords will not be changed.',
            confirmText: 'Restore');
          if (!confirmed) return;
          await store.restore(backup);
          if (context.mounted) showSuccess(context, 'Local data restored successfully');
        } catch (e) { showFailure(context, e); }
      }, icon: Icons.restore),
      const SizedBox(height: 20),
      const Text('Cloud backup: Not connected. Export a backup before changing phones '
        'or uninstalling the app.', style: TextStyle(fontSize: 12)),
    ]));
}

class ScannerTestScreen extends StatefulWidget {
  final bool diagnostics;
  const ScannerTestScreen({super.key, this.diagnostics = false});
  @override
  State<ScannerTestScreen> createState() => _ScannerTestScreenState();
}

class _ScannerTestScreenState extends State<ScannerTestScreen> {
  final controller = TextEditingController();
  final focus = FocusNode();
  Timer? timer;
  final List<(String, DateTime)> results = [];
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) focus.requestFocus(); });
  }
  void changed(String text) {
    timer?.cancel();
    if (text.trim().isNotEmpty) {
      timer = Timer(const Duration(milliseconds: 650), () => capture(controller.text));
    }
  }
  void capture(String raw) {
    timer?.cancel(); controller.clear();
    final values = raw.split(RegExp(r'[\r\n]+')).where((e) => e.trim().isNotEmpty);
    if (mounted) setState(() {
      for (final v in values) { results.insert(0, (v.trim(), DateTime.now())); }
    });
    if (mounted) FocusScope.of(context).requestFocus(focus);
  }
  @override
  void dispose() { timer?.cancel(); controller.dispose(); focus.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(widget.diagnostics ?
    'Scanner Diagnostics' : 'Barcode Scanner Test')),
    body: ListView(padding: const EdgeInsets.all(18), children: [
      const Text('Scan any 1D barcode or 2D QR code with your physical scanner. '
        'The exact text, character count and time will appear below.'),
      const SizedBox(height: 12),
      TextField(controller: controller, focusNode: focus,
        keyboardType: TextInputType.none,
        decoration: const InputDecoration(labelText: 'Tap here and scan'),
        onChanged: changed, onSubmitted: capture),
      const SizedBox(height: 15),
      Text('Captured Scans (${results.length})', style: Theme.of(context).textTheme.titleMedium),
      if (results.isEmpty) emptyView('Waiting for scanner input…'),
      ...results.map((r) => Card(child: ListTile(
        title: Text(r.$1),
        subtitle: Text('${r.$1.length} characters · ${r.$2.toLocal()}'),
        trailing: Icon(RegExp(r'^\d+$').hasMatch(r.$1) ?
          Icons.check_circle_outline : Icons.info_outline)))),
      TextButton(onPressed: () => setState(results.clear), child: const Text('Clear Scan History')),
    ]));
}
