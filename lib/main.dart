import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'store.dart';
import 'screens/auth.dart';
import 'screens/dashboard.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Never expose Flutter's default red error screen to field employees.
  // The fallback includes a retry action, while diagnostics remain in logs.
  ErrorWidget.builder = (details) => Material(
    color: const Color(0xFFF1F5F9),
    child: Center(child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline, size: 48, color: Color(0xFF173457)),
        const SizedBox(height: 12),
        const Text('Something went wrong', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Please reopen this screen. Your saved audit data is not intentionally deleted.', textAlign: TextAlign.center),
      ]),
    )),
  );
  final store = RetailStore();
  try {
    await store.load();
    await Firebase.initializeApp();
    runApp(RetailSAuditApp(store: store));
  } catch (error, stack) {
    debugPrint('RetailSAudit startup failure: $error\n$stack');
    runApp(MaterialApp(home: Scaffold(body: SafeArea(child: Center(
      child: Padding(padding: const EdgeInsets.all(24), child: Column(
        mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.warning_amber_rounded, size: 48),
          const SizedBox(height: 16),
          const Text('RetailSAudit could not start. No audit data has been intentionally erased.', textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: () => main(), child: const Text('Try Again')),
        ],
      )),
    )))));
  }
}

class RetailSAuditApp extends StatelessWidget {
  final RetailStore store;
  const RetailSAuditApp({super.key, required this.store});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) {
      const navy = Color(0xFF142B49);
      const teal = Color(0xFF00A6A0);
      final dark = store.darkMode;
      final base = ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: teal,
          primary: dark ? const Color(0xFF63DDD4) : navy,
          secondary: teal,
          brightness: dark ? Brightness.dark : Brightness.light,
          contrastLevel: store.highContrast ? 1.0 : 0.0,
        ),
        scaffoldBackgroundColor: dark ? const Color(0xFF0E1929) : const Color(0xFFF4F7FB),
        appBarTheme: AppBarTheme(
          centerTitle: false, elevation: 0, scrolledUnderElevation: 0,
          backgroundColor: dark ? const Color(0xFF0E1929) : const Color(0xFFF4F7FB),
          titleTextStyle: TextStyle(fontSize: 21, fontWeight: FontWeight.w800,
            color: dark ? Colors.white : navy),
        ),
        cardTheme: CardThemeData(
          elevation: 0, color: dark ? const Color(0xFF1A2A3E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: dark ? const Color(0xFF1A2A3E) : Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: dark ? const Color(0xFF34475D) : const Color(0xFFE2E8F0))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: teal, width: 2)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
        ),
        filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)))),
        elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)))),
      );
      return MaterialApp(
        title: 'RetailSAudit', debugShowCheckedModeBanner: false,
        theme: base,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(store.textScale)),
          child: child ?? const SizedBox.shrink()),
        home: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, session) {
            final user = session.data;
            if (user == null) {
              if (store.currentUser != null) store.clearCloudUser();
              return AuthScreen(store: store);
            }
            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
              builder: (context, profile) {
                if (!profile.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
                final data = profile.data!.data();
                if (data == null || data['active'] != true) {
                  FirebaseAuth.instance.signOut();
                  return const Scaffold(body: Center(child: Text('Account suspended or not provisioned')));
                }
                store.setCloudUser(data);
                return DashboardScreen(store: store);
              },
            );
          },
        ),
      );
    },
  );
}

void showFailure(BuildContext context, Object error) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
}

void showSuccess(BuildContext context, String text) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

Widget emptyView(String text) => Padding(
  padding: const EdgeInsets.all(24),
  child: Center(child: Text(text, textAlign: TextAlign.center)));

Widget actionButton(String text, VoidCallback onPressed, {IconData? icon}) =>
    SizedBox(width: double.infinity, child: ElevatedButton.icon(
      onPressed: onPressed, icon: Icon(icon ?? Icons.arrow_forward_rounded), label: Text(text)));

Future<bool> confirmAction(BuildContext context, String title, String message,
    {String confirmText = 'Confirm'}) async => await showDialog<bool>(
  context: context,
  builder: (dialogContext) => AlertDialog(
    title: Text(title), content: Text(message),
    actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false),
      child: const Text('Cancel')),
      FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
        child: Text(confirmText))],
  )) ?? false;
