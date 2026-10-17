import 'package:flutter/material.dart';
import 'store.dart';
import 'screens/auth.dart';
import 'screens/dashboard.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = RetailStore();
  await store.load();
  runApp(RetailSAuditApp(store: store));
}

class RetailSAuditApp extends StatelessWidget {
  final RetailStore store;
  const RetailSAuditApp({super.key, required this.store});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) {
      const navy = Color(0xFF173457);
      final base = ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: navy,
          brightness: store.darkMode ? Brightness.dark : Brightness.light,
          contrastLevel: store.highContrast ? 1.0 : 0.0),
        scaffoldBackgroundColor: store.darkMode ? const Color(0xFF101D2E) :
            const Color(0xFFF1F5F9),
        appBarTheme: const AppBarTheme(centerTitle: false),
        cardTheme: CardThemeData(elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15)),
        elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))),
      );
      return MaterialApp(
        title: 'RetailSAudit', debugShowCheckedModeBanner: false,
        theme: base,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(store.textScale)),
          child: child ?? const SizedBox.shrink()),
        home: store.currentUser == null ? AuthScreen(store: store) : DashboardScreen(store: store),
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
