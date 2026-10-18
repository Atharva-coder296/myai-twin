import 'package:flutter/material.dart';
import '../cloud_accounts.dart';
import '../main.dart';
import '../store.dart';

class AuthScreen extends StatefulWidget {
  final RetailStore store;
  const AuthScreen({super.key, required this.store});
  @override State<AuthScreen> createState() => _AuthScreenState();
}
class _AuthScreenState extends State<AuthScreen> {
  final id = TextEditingController();
  final password = TextEditingController();
  bool busy = false;
  @override void dispose() { id.dispose(); password.dispose(); super.dispose(); }
  Future<void> submit() async {
    if (busy) return;
    setState(() => busy = true);
    try { await CloudAccounts.signIn(id.text, password.text); }
    catch (e) { if (mounted) showFailure(context, 'Cloud sign-in failed: $e'); }
    finally { if (mounted) setState(() => busy = false); }
  }
  @override Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(24), children: [
        Container(width: 80, height: 80, alignment: Alignment.center,
          decoration: BoxDecoration(color: const Color(0xFF142B49),
            borderRadius: BorderRadius.circular(23)),
          child: const Icon(Icons.inventory_2_rounded, size: 42, color: Color(0xFF74E5DC))),
        const SizedBox(height: 26),
        Text('Welcome back', style: Theme.of(context).textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text('Sign in to RetailSAudit', style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 32),
        const Text('EMAIL ADDRESS', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1)),
        const SizedBox(height: 9),
        TextField(controller: id, keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(prefixIcon: Icon(Icons.mail_outline_rounded),
            hintText: 'employee@example.com')),
        const SizedBox(height: 20),
        const Text('PASSWORD', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1)),
        const SizedBox(height: 9),
        TextField(controller: password, obscureText: true,
          decoration: const InputDecoration(prefixIcon: Icon(Icons.lock_outline_rounded),
            hintText: 'Enter your password')),
        const SizedBox(height: 26),
        FilledButton.icon(onPressed: busy ? null : submit,
          icon: const Icon(Icons.login_rounded),
          label: Text(busy ? 'Signing in…' : 'Sign In')),
        const SizedBox(height: 22),
        Text('Secure access for authorized RetailSAudit staff',
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
      ]),
    ))),
  );
}
