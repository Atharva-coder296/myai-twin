import 'package:flutter/material.dart';
import '../store.dart';
import 'audit.dart';
import 'reports.dart';
import 'settings.dart';
import 'upload.dart';

class DashboardScreen extends StatelessWidget {
  final RetailStore store;
  const DashboardScreen({super.key, required this.store});
  @override
  Widget build(BuildContext context) {
    final tiles = <(String, IconData, Widget)>[
      ('Upload Data', Icons.upload_file, UploadScreen(store: store)),
      ('Start Scanning', Icons.qr_code_scanner, AuditEntryScreen(store: store)),
      ('Settings', Icons.settings_outlined, SettingsScreen(store: store)),
      ('View Report', Icons.description_outlined, ReportHomeScreen(store: store)),
      ('Clear Data', Icons.delete_outline, DeleteScreen(store: store)),
      ('Variance Report', Icons.analytics_outlined, VarianceGeneratorScreen(store: store)),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('RetailSAudit'),
        actions: [IconButton(tooltip: 'Log out', onPressed: store.signOut,
          icon: const Icon(Icons.logout))]),
      body: ListView(padding: const EdgeInsets.all(18), children: [
        Card(color: Theme.of(context).colorScheme.primary,
          child: Padding(padding: const EdgeInsets.all(18), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Welcome, ${store.currentUser?.name ?? 'Auditor'}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white)),
              const SizedBox(height: 5),
              Text('${store.isAdmin ? 'Administrator' : 'Employee'} • ${store.currentUser?.id ?? ''}',
                style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 7),
              const Text('Audits are currently saved on this device',
                style: TextStyle(color: Colors.white70, fontSize: 12)),
            ]))),
        if (store.draft != null) Padding(padding: const EdgeInsets.only(bottom: 8),
          child: Card(child: ListTile(leading: const Icon(Icons.play_circle_outline),
            title: const Text('Unfinished Audit'),
            subtitle: Text('${store.draft!.brand} · ${store.draft!.racks.length} rack(s)'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => ActiveAuditScreen(store: store))))),
        ),
        const SizedBox(height: 10),
        GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          itemCount: tiles.length,
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 230, childAspectRatio: 1.35,
            mainAxisSpacing: 12, crossAxisSpacing: 12),
          itemBuilder: (context, i) {
            final (name, icon, page) = tiles[i];
            return Card(clipBehavior: Clip.antiAlias, child: InkWell(
              onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => page)),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icon, size: 33, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 10),
                Text(name, textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              ])));
          }),
      ]),
    );
  }
}
