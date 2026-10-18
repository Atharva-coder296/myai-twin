import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../cloud_accounts.dart';
import 'employee_registration.dart';
import '../main.dart';

class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({super.key});
  @override State<EmployeesScreen> createState() => _EmployeesScreenState();
}
class _EmployeesScreenState extends State<EmployeesScreen> {
  String? orgId;
  @override void initState() {
    super.initState();
    FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser!.uid)
      .get().then((d) { if (mounted) setState(() => orgId = d.data()?['orgId'] as String?); });
  }
  Future<void> suspend(String uid, String name) async {
    final confirmed = await confirmAction(context, 'Suspend $name?',
      'This blocks protected Firestore access and signs out connected app sessions when online. It does not disable the Firebase Auth account itself. Continue?', confirmText: 'Suspend');
    if (!confirmed) return;
    try { await CloudAccounts.suspend(uid); }
    catch (e) { if (mounted) showFailure(context, e); }
  }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Employees')),
    floatingActionButton: FloatingActionButton.extended(onPressed: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => const EmployeeRegistrationScreen())),
      icon: const Icon(Icons.person_add), label: const Text('Add User')),
    body: orgId == null ? const Center(child: CircularProgressIndicator()) :
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: CloudAccounts.employees(orgId!), builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Unable to load employees: ${snapshot.error}'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final employees = snapshot.data!.docs.where((d) => d.data()['role'] == 'employee').toList();
          if (employees.isEmpty) return const Center(child: Text('No employees yet'));
          return ListView.builder(itemCount: employees.length, itemBuilder: (ctx, i) {
            final doc = employees[i], data = doc.data();
            return ListTile(title: Text('${data['name'] ?? 'Employee'}'),
              subtitle: Text('${data['id'] ?? ''} • ${data['active'] == true ? 'Active account' : 'Suspended'}'),
              trailing: const Icon(Icons.touch_app),
              onLongPress: data['active'] == true ? () => suspend(doc.id, '${data['name']}') : null);
          });
        },
      ),
  );
}
