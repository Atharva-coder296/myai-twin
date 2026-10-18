import 'package:flutter/material.dart';
import 'employees.dart';
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
    if (store.isAdmin) tiles.insert(0, ('Manage Employees', Icons.manage_accounts, const EmployeesScreen()));
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('RetailSAudit'), actions: [
        IconButton(tooltip: 'Log out', onPressed: store.signOut,
          icon: const Icon(Icons.logout_rounded)),
        const SizedBox(width: 8),
      ]),
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 12, 18, 32), children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFF142B49), Color(0xFF1B5370)]),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.verified_user_outlined, color: Color(0xFF74E5DC), size: 19),
              SizedBox(width: 8),
              Text('RETAIL OPERATIONS', style: TextStyle(
                color: Color(0xFF74E5DC), fontSize: 11,
                fontWeight: FontWeight.w800, letterSpacing: 1.5)),
            ]),
            const SizedBox(height: 20),
            Text('Hello, ${store.currentUser?.name ?? 'Auditor'}',
              style: const TextStyle(color: Colors.white,
                fontSize: 25, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('${store.isAdmin ? 'Administrator' : 'Employee'}  •  ${store.currentUser?.id ?? ''}',
              style: const TextStyle(color: Color(0xFFD6E6EE), fontSize: 13)),
            const SizedBox(height: 20),
            Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(color: const Color(0x22FFFFFF),
                borderRadius: BorderRadius.circular(12)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.phone_android_rounded, color: Colors.white70, size: 16),
                SizedBox(width: 7),
                Flexible(child: Text('Audit data saved on this device',
                  style: TextStyle(color: Colors.white70, fontSize: 12))),
              ])),
          ]),
        ),
        if (store.draft != null) Padding(
          padding: const EdgeInsets.only(top: 18),
          child: Card(child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            leading: const Icon(Icons.play_circle_fill_rounded, color: Color(0xFF00A6A0), size: 34),
            title: const Text('Resume unfinished audit', style: TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text('${store.draft!.brand} • ${store.draft!.racks.length} locations'),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 17),
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => ActiveAuditScreen(store: store))),
          )),
        ),
        const SizedBox(height: 25),
        Text('Quick actions', style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800)),
        const SizedBox(height: 5),
        Text('Everything you need for your next audit',
          style: TextStyle(color: colors.onSurfaceVariant)),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          itemCount: tiles.length,
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 230, childAspectRatio: 1.17,
            mainAxisSpacing: 12, crossAxisSpacing: 12),
          itemBuilder: (context, i) {
            final (name, icon, page) = tiles[i];
            return Card(clipBehavior: Clip.antiAlias, child: InkWell(
              onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => page)),
              child: Padding(padding: const EdgeInsets.all(15),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: colors.secondary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(13)),
                    child: Icon(icon, size: 25, color: colors.secondary)),
                  const Spacer(),
                  Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                  const SizedBox(height: 5),
                  Icon(Icons.arrow_outward_rounded, size: 16, color: colors.onSurfaceVariant),
                ])),
            ));
          },
        ),
      ]),
    );
  }
}
