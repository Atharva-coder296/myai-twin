import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class CloudAccounts {
  static String loginEmail(String value) => value.trim().toLowerCase();
  static Future<UserCredential> signIn(String email, String password) =>
      FirebaseAuth.instance.signInWithEmailAndPassword(
          email: loginEmail(email), password: password);

  static Stream<QuerySnapshot<Map<String, dynamic>>> employees(String orgId) =>
      FirebaseFirestore.instance.collection('users')
          .where('orgId', isEqualTo: orgId).snapshots();

  /// Creates an Auth identity in an isolated secondary Firebase app, keeping
  /// the administrator signed in on the primary Firebase app.
  /// WARNING: Firebase Auth sign-up is a public client API; Firestore rules
  /// protect authorization but cannot prevent arbitrary Auth sign-ups.
  static Future<String> registerEmployee({
    required String name,
    required String email,
    required String phone,
    required String employeeId,
    required String password,
  }) async {
    final admin = FirebaseAuth.instance.currentUser;
    if (admin == null) throw StateError('Administrator must sign in first.');
    final db = FirebaseFirestore.instance;
    final adminDoc = await db.collection('users').doc(admin.uid).get();
    final profile = adminDoc.data();
    if (profile == null || profile['active'] != true || profile['role'] != 'admin') {
      throw StateError('Active administrator account required.');
    }
    final orgId = profile['orgId'];
    if (orgId is! String || orgId.isEmpty) throw StateError('Admin organization missing.');
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedId = employeeId.trim();
    final existingId = await db.collection('users')
        .where('orgId', isEqualTo: orgId)
        .where('id', isEqualTo: normalizedId).limit(1).get();
    if (existingId.docs.isNotEmpty) throw StateError('Employee ID already in use.');

    FirebaseApp? secondary;
    User? created;
    try {
      secondary = await Firebase.initializeApp(
          name: 'employee-registration', options: Firebase.app().options);
      final auth = FirebaseAuth.instanceFor(app: secondary);
      final credential = await auth.createUserWithEmailAndPassword(
          email: normalizedEmail, password: password);
      created = credential.user;
      if (created == null) throw StateError('Firebase did not return an employee UID.');
      await db.collection('users').doc(created.uid).set({
        'active': true,
        'role': 'employee',
        'orgId': orgId,
        'name': name.trim(),
        'id': normalizedId,
        'email': normalizedEmail,
        'phone': phone.trim(),
      });
      return created.uid;
    } catch (_) {
      // Best-effort cleanup if profile creation failed after Auth signup.
      if (created != null) {
        try { await created.delete(); } catch (_) { /* Requires manual cleanup in console. */ }
      }
      rethrow;
    } finally {
      if (secondary != null) {
        try { await FirebaseAuth.instanceFor(app: secondary).signOut(); } catch (_) {}
        await secondary.delete();
      }
    }
  }

  static Future<void> suspend(String uid) => FirebaseFirestore.instance
      .collection('users').doc(uid).update({'active': false});
  static Future<void> reactivate(String uid) => FirebaseFirestore.instance
      .collection('users').doc(uid).update({'active': true});
}
