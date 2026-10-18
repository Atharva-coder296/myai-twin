import 'package:flutter/material.dart';
import '../cloud_accounts.dart';

class EmployeeRegistrationScreen extends StatefulWidget {
  const EmployeeRegistrationScreen({super.key});
  @override
  State<EmployeeRegistrationScreen> createState() => _EmployeeRegistrationScreenState();
}

class _EmployeeRegistrationScreenState extends State<EmployeeRegistrationScreen> {
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  final employeeId = TextEditingController();
  final password = TextEditingController();
  bool busy = false;
  bool visible = false;

  @override
  void dispose() {
    for (final controller in [name, email, phone, employeeId, password]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> register() async {
    if (busy || !(formKey.currentState?.validate() ?? false)) return;
    setState(() => busy = true);
    try {
      await CloudAccounts.registerEmployee(
        name: name.text, email: email.text, phone: phone.text,
        employeeId: employeeId.text, password: password.text);
      if (!mounted) return;
      await showDialog<void>(context: context, builder: (context) => AlertDialog(
        title: const Text('Employee registered'),
        content: Text('Employee ID: ${employeeId.text.trim()}\n'
          'Login email: ${email.text.trim().toLowerCase()}\n\n'
          'Give the employee their password securely. Passwords are not saved in Firestore.'),
        actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))],
      ));
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Registration failed: $error')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget field(TextEditingController controller, String label, {
    TextInputType? keyboardType, bool obscure = false, String? Function(String?)? validator,
  }) => Padding(padding: const EdgeInsets.only(bottom: 12), child: TextFormField(
    controller: controller, keyboardType: keyboardType, obscureText: obscure,
    autocorrect: false,
    decoration: InputDecoration(labelText: label),
    validator: validator ?? (value) => (value?.trim().isEmpty ?? true) ? 'Required' : null,
  ));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Employee Registration')),
    body: Form(key: formKey, child: ListView(padding: const EdgeInsets.all(18), children: [
      field(name, 'Employee full name'),
      field(email, 'Email ID', keyboardType: TextInputType.emailAddress,
        validator: (v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v?.trim() ?? '')
            ? null : 'Enter a valid email'),
      field(phone, 'Phone number', keyboardType: TextInputType.phone,
        validator: (v) => RegExp(r'^[0-9]{10}$').hasMatch(v?.trim() ?? '')
            ? null : 'Enter a 10-digit phone number'),
      field(employeeId, 'Employee ID', validator: (v) =>
        RegExp(r'^[A-Za-z0-9_-]{3,30}$').hasMatch(v?.trim() ?? '')
            ? null : 'Use 3–30 letters, numbers, _ or -'),
      Padding(padding: const EdgeInsets.only(bottom: 12), child: TextFormField(
        controller: password, obscureText: !visible,
        decoration: InputDecoration(labelText: 'Password', suffixIcon: IconButton(
          onPressed: () => setState(() => visible = !visible),
          icon: Icon(visible ? Icons.visibility_off : Icons.visibility))),
        validator: (v) => (v?.length ?? 0) < 12 ? 'Use at least 12 characters' : null,
      )),
      const Text('Employees sign in using their email and password. Employee ID is their staff identifier.'),
      const SizedBox(height: 16),
      FilledButton.icon(onPressed: busy ? null : register,
        icon: const Icon(Icons.person_add_alt_1),
        label: Text(busy ? 'Registering…' : 'Register Employee')),
    ])),
  );
}
