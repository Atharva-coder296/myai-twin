import 'package:flutter/material.dart';
import '../main.dart';
import '../store.dart';

class AuthScreen extends StatefulWidget {
  final RetailStore store;
  const AuthScreen({super.key, required this.store});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final id = TextEditingController(text: RetailStore.primaryAdminId);
  final password = TextEditingController();
  final confirm = TextEditingController();
  bool busy = false;
  bool obscure = true;
  @override
  void dispose() { id.dispose(); password.dispose(); confirm.dispose(); super.dispose(); }

  Future<void> submit() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      if (!widget.store.hasAccounts) {
        if (password.text != confirm.text) throw ArgumentError('Passwords do not match');
        if (password.text.length < 10) throw ArgumentError('Use at least 10 characters');
        await widget.store.setUpPrimaryAdmin(password.text);
        await widget.store.signIn(RetailStore.primaryAdminId, password.text);
      } else {
        if (!await widget.store.signIn(id.text, password.text)) {
          throw StateError('Incorrect User ID or password');
        }
      }
    } catch (e) {
      if (mounted) showFailure(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final setup = !widget.store.hasAccounts;
    return Scaffold(body: SafeArea(child: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(24), children: [
        const CircleAvatar(radius: 39, child: Icon(Icons.inventory_2_outlined, size: 39)),
        const SizedBox(height: 15),
        Text('RetailSAudit', textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w800)),
        const Text('The Retail Audit & Allied Services', textAlign: TextAlign.center),
        const SizedBox(height: 25),
        Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(setup ? 'Create Primary Admin' : 'Sign in',
            style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 15),
          if (setup) ...[
            const Text('Primary Admin ID: RetailSAudit', style: TextStyle(fontWeight: FontWeight.bold)),
            const Text('Admin/report email: retailsaudit@gmail.com'),
            const SizedBox(height: 12),
          ] else ...[
            TextField(controller: id, decoration: const InputDecoration(labelText: 'User ID or email')),
            const SizedBox(height: 12),
          ],
          TextField(controller: password, obscureText: obscure,
            decoration: InputDecoration(labelText: setup ? 'Create password' : 'Password',
              suffixIcon: IconButton(icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => obscure = !obscure)))),
          if (setup) ...[
            const SizedBox(height: 12),
            TextField(controller: confirm, obscureText: obscure,
                decoration: const InputDecoration(labelText: 'Confirm password')),
          ],
          const SizedBox(height: 16),
          actionButton(busy ? 'Please wait…' : setup ? 'Create Admin Account' : 'Sign In',
            busy ? () {} : submit, icon: Icons.lock_open),
        ]))),
        const SizedBox(height: 15),
        const Text('LOCAL DEMONSTRATION • Accounts and reports currently stay on this device. '
          'The production release requires Firebase authentication and cloud-backed permissions.',
          textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
      ]),
    ))));
  }
}
