import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'models.dart';

class RetailStore extends ChangeNotifier {
  static const primaryAdminId = 'RetailSAudit';
  static const primaryAdminEmail = 'retailsaudit@gmail.com';
  static const storageKey = 'retailsaudit_flutter_local_v1';

  final List<Account> accounts = [];
  final List<Audit> reports = [];
  final List<VarianceReport> varianceReports = [];
  final List<SohRow> soh = [];
  final List<String> locationBarcodes = [];
  final List<String> locationFileNames = [];
  final List<String> productBarcodes = [];
  Account? currentUser;
  Audit? draft;
  int activeDraftRackIndex = 0;
  String sohFileName = '';
  String adminEmail = primaryAdminEmail;
  String supportEmail = '';
  bool successSound = true;
  bool mismatchSound = true;
  bool vibration = false;
  bool confirmEnd = true;
  bool autoSave = true;
  bool highContrast = false;
  bool darkMode = false;
  double textScale = 1.0;
  bool loaded = false;
  late SharedPreferences _prefs;

  bool get isAdmin => currentUser?.isAdmin == true;
  bool get hasAccounts => accounts.isNotEmpty;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs.getString(storageKey);
    if (raw != null) {
      try {
        final j = Map<String, dynamic>.from(jsonDecode(raw));
        accounts.addAll((j['accounts'] as List? ?? []).map((e) => Account.fromJson(Map<String, dynamic>.from(e))));
        reports.addAll((j['reports'] as List? ?? []).map((e) => Audit.fromJson(Map<String, dynamic>.from(e))));
        varianceReports.addAll((j['varianceReports'] as List? ?? []).map((e) => VarianceReport.fromJson(Map<String, dynamic>.from(e))));
        soh.addAll((j['soh'] as List? ?? []).map((e) => SohRow.fromJson(Map<String, dynamic>.from(e))));
        locationBarcodes.addAll(List<String>.from(j['locationBarcodes'] ?? []));
        locationFileNames.addAll(List<String>.from(j['locationFileNames'] ?? []));
        productBarcodes.addAll(List<String>.from(j['productBarcodes'] ?? []));
        if (j['draft'] != null) draft = Audit.fromJson(Map<String, dynamic>.from(j['draft']));
        activeDraftRackIndex = asInt(j['activeDraftRackIndex']);
        sohFileName = '${j['sohFileName'] ?? ''}';
        adminEmail = '${j['adminEmail'] ?? primaryAdminEmail}';
        supportEmail = '${j['supportEmail'] ?? ''}';
        successSound = j['successSound'] != false;
        mismatchSound = j['mismatchSound'] != false;
        vibration = j['vibration'] == true;
        confirmEnd = j['confirmEnd'] != false;
        autoSave = j['autoSave'] != false;
        darkMode = j['darkMode'] == true;
        highContrast = j['highContrast'] == true;
        textScale = (j['textScale'] as num?)?.toDouble() ?? 1.0;
      } catch (_) {
        // Preserve the existing storage rather than overwriting an unreadable file.
      }
    }
    loaded = true;
    notifyListeners();
  }

  Future<void> save() async {
    await _prefs.setString(storageKey, prettyJson(snapshot()));
    notifyListeners();
  }

  Map<String, dynamic> snapshot() => {
    'schema': 1,
    // Authentication hashes belong to a local demonstration only, not production.
    'accounts': accounts.map((e) => e.toJson()).toList(),
    'reports': reports.map((e) => e.toJson()).toList(),
    'varianceReports': varianceReports.map((e) => e.toJson()).toList(),
    'soh': soh.map((e) => e.toJson()).toList(),
    'locationBarcodes': locationBarcodes,
    'locationFileNames': locationFileNames,
    'productBarcodes': productBarcodes,
    'draft': draft?.toJson(), 'activeDraftRackIndex': activeDraftRackIndex,
    'sohFileName': sohFileName,
    'adminEmail': adminEmail, 'supportEmail': supportEmail,
    'successSound': successSound, 'mismatchSound': mismatchSound,
    'vibration': vibration, 'confirmEnd': confirmEnd,
    'autoSave': autoSave, 'darkMode': darkMode,
    'highContrast': highContrast, 'textScale': textScale,
  };

  // This local account system is intended ONLY for prototype testing.
  // Production must replace it with Firebase Auth + backend-enforced roles.
  final Pbkdf2 _passwordKdf = Pbkdf2(
    macAlgorithm: Hmac.sha256(), iterations: 120000, bits: 256);

  String _freshSalt() {
    final random = Random.secure();
    return base64Encode(List<int>.generate(16, (_) => random.nextInt(256)));
  }

  Future<String> _hash(String password, String salt) async {
    final key = await _passwordKdf.deriveKeyFromPassword(
      password: password, nonce: base64Decode(salt));
    return base64Encode(await key.extractBytes());
  }

  Future<void> setUpPrimaryAdmin(String password) async {
    if (hasAccounts) throw StateError('Primary administrator already configured');
    if (password.length < 10) throw ArgumentError('Use at least 10 characters');
    final salt = _freshSalt();
    accounts.add(Account(id: primaryAdminId, name: 'Primary Admin',
      email: primaryAdminEmail, phone: '', role: 'admin', salt: salt,
      passwordHash: await _hash(password, salt)));
    await save();
  }

  Future<bool> signIn(String id, String password) async {
    Account? found;
    for (final account in accounts) {
      if (account.id.toLowerCase() == id.trim().toLowerCase() ||
          account.email.toLowerCase() == id.trim().toLowerCase()) {
        found = account;
        break;
      }
    }
    if (found == null || found.suspended) return false;
    final supplied = await _hash(password, found.salt);
    // Constant-time hash comparison (local demo, not a production security boundary).
    final a = base64Decode(supplied), b = base64Decode(found.passwordHash);
    if (a.length != b.length) return false;
    var difference = 0;
    for (var i = 0; i < a.length; i++) { difference |= a[i] ^ b[i]; }
    if (difference != 0) return false;
    currentUser = found;
    notifyListeners();
    return true;
  }

  void setCloudUser(Map<String, dynamic> data) {
    final id = '${data['id'] ?? ''}';
    if (currentUser?.id == id && currentUser?.role == data['role']) return;
    currentUser = Account(id: id, name: '${data['name'] ?? id}',
      email: '${data['email'] ?? ''}', phone: '',
      role: '${data['role'] ?? 'employee'}', salt: '', passwordHash: '');
    WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());
  }
  void clearCloudUser() {
    if (currentUser == null) return;
    currentUser = null;
    WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());
  }
  void signOut() {
    FirebaseAuth.instance.signOut();
    currentUser = null;
    notifyListeners();
  }

  Future<String> addAccount({required String name, required String email,
    required String phone, required bool admin, required String password}) async {
    if (!isAdmin) throw StateError('Administrator access required');
    if (name.trim().isEmpty || email.trim().isEmpty || password.length < 10) {
      throw ArgumentError('Enter name, email and password of at least 10 characters');
    }
    final id = admin ? 'ADMIN-${accounts.length + 1}' : 'EMP-${accounts.length + 1}';
    if (accounts.any((e) => e.email.toLowerCase() == email.toLowerCase())) {
      throw ArgumentError('Email already registered');
    }
    final salt = _freshSalt();
    accounts.add(Account(id: id, name: name.trim(), email: email.trim(),
      phone: phone.trim(), role: admin ? 'admin' : 'employee', salt: salt,
      passwordHash: await _hash(password, salt)));
    await save();
    return id;
  }

  Future<void> suspendAccount(String id) async {
    if (!isAdmin) throw StateError('Administrator access required');
    final account = accounts.firstWhere((a) => a.id == id);
    if (account.isAdmin) throw StateError('Admin accounts cannot be suspended here');
    account.suspended = true;
    await save();
  }

  Future<void> deleteRack(Audit audit, int index) async {
    if (index < 0 || index >= audit.racks.length) return;
    if (audit.racks.length == 1) throw StateError('At least one location is required');
    audit.racks.removeAt(index);
    if (identical(draft, audit)) {
      activeDraftRackIndex = activeDraftRackIndex.clamp(0, audit.racks.length - 1).toInt();
    }
    await save();
  }

  Future<void> startAudit({required String brand, required String storeCode,
    required int barcodeLength, required String auditor, required String rack}) async {
    if (draft != null) throw StateError('Finish or resume the current audit first');
    if (barcodeLength < 1 || barcodeLength > 128) throw ArgumentError('Barcode length must be 1–128');
    activeDraftRackIndex = 0;
    draft = Audit(id: newId(), name: '', brand: brand.trim(), storeCode: storeCode.trim(),
      eanLength: barcodeLength, date: today(), racks: [RackCount(id: newId(),
        rack: rack.trim(), auditor: auditor.trim(), date: today())]);
    await save();
  }

  Future<void> addRack(String rack, String auditor) async {
    if (draft == null) throw StateError('No active audit');
    draft!.racks.add(RackCount(id: newId(), rack: rack.trim(),
      auditor: auditor.trim(), date: today()));
    activeDraftRackIndex = draft!.racks.length - 1;
    await save();
  }

  Future<void> setActiveDraftRack(int index) async {
    if (draft == null || index < 0 || index >= draft!.racks.length) return;
    activeDraftRackIndex = index;
    await save();
  }

  Future<void> scan({required int rackIndex, required String barcode}) async {
    if (draft == null) throw StateError('No active audit');
    if (!validBarcode(barcode)) throw ArgumentError('Barcode cannot be empty');
    draft!.racks[rackIndex].scan(barcode);
    await save(); // Always auto-save each scan; disabling this would risk data loss.
  }

  Future<void> changeExpectedLength(int newLength) async {
    if (draft == null || newLength < 1 || newLength > 128) {
      throw ArgumentError('Invalid barcode length');
    }
    draft!.eanLength = newLength;
    await save();
  }

  Future<void> editCount(Audit audit, int rackIndex, int rowIndex,
      String barcode, int quantity) async {
    if (!validBarcode(barcode) || quantity < 0) throw ArgumentError('Invalid count');
    final rack = audit.racks[rackIndex];
    // Apply the edited quantity first, then merge into an existing barcode if needed.
    rack.rows[rowIndex].quantity = quantity;
    rack.editBarcode(rowIndex, barcode);
    await save();
  }

  Future<void> completeAudit(String name) async {
    if (draft == null || name.trim().isEmpty) throw ArgumentError('Enter audit name');
    draft!.name = name.trim();
    reports.removeWhere((a) => a.id == draft!.id);
    reports.insert(0, draft!);
    draft = null;
    activeDraftRackIndex = 0;
    await save();
  }

  Future<void> setSoh(List<SohRow> rows, String fileName) async {
    soh..clear()..addAll(rows);
    sohFileName = fileName;
    await save();
  }

  Future<void> setLocationBarcodes(List<String> codes, String fileName) async {
    locationBarcodes..clear()..addAll(codes);
    locationFileNames..clear()..add(fileName);
    await save();
  }

  Future<void> addImportedAudit(Audit audit) async {
    reports.insert(0, audit);
    await save();
  }

  Future<VarianceReport> makeVariance(Audit audit) async {
    if (soh.isEmpty) throw StateError('Upload SOH before creating variance');
    final report = VarianceReport(id: newId(), auditId: audit.id,
      name: 'Variance — ${audit.name}', date: today(),
      lines: calculateVariance(audit, soh));
    varianceReports.insert(0, report);
    await save();
    return report;
  }

  Future<void> deleteReport(String id) async {
    reports.removeWhere((a) => a.id == id);
    await save();
  }
  Future<void> deleteVariance(String id) async {
    varianceReports.removeWhere((a) => a.id == id);
    await save();
  }
  Future<void> deleteSoh() async {
    soh.clear(); sohFileName = '';
    await save();
  }
  Future<void> deleteLocationList() async {
    locationBarcodes.clear(); locationFileNames.clear();
    await save();
  }

  Future<void> updatePreferences({bool? successSound, bool? mismatchSound,
    bool? vibration, bool? confirmEnd, bool? darkMode, bool? highContrast,
    double? textScale, String? adminEmail, String? supportEmail}) async {
    if (successSound != null) this.successSound = successSound;
    if (mismatchSound != null) this.mismatchSound = mismatchSound;
    if (vibration != null) this.vibration = vibration;
    if (confirmEnd != null) this.confirmEnd = confirmEnd;
    if (darkMode != null) this.darkMode = darkMode;
    if (highContrast != null) this.highContrast = highContrast;
    if (textScale != null) this.textScale = textScale;
    if (adminEmail != null && isAdmin) this.adminEmail = adminEmail;
    if (supportEmail != null && isAdmin) this.supportEmail = supportEmail;
    await save();
  }

  Future<void> restore(Map<String, dynamic> backup) async {
    if (!isAdmin) throw StateError('Administrator access required');
    if (backup['schema'] != 1 || backup['reports'] is! List || backup['accounts'] is! List) {
      throw FormatException('Invalid RetailSAudit backup');
    }
    // Keep current account credentials to prevent importing an unknown admin account.
    reports..clear()..addAll((backup['reports'] as List).map((e) => Audit.fromJson(Map<String, dynamic>.from(e))));
    varianceReports..clear()..addAll((backup['varianceReports'] as List? ?? [])
        .map((e) => VarianceReport.fromJson(Map<String, dynamic>.from(e))));
    soh..clear()..addAll((backup['soh'] as List? ?? [])
        .map((e) => SohRow.fromJson(Map<String, dynamic>.from(e))));
    locationBarcodes..clear()..addAll(List<String>.from(backup['locationBarcodes'] ?? []));
    locationFileNames..clear()..addAll(List<String>.from(backup['locationFileNames'] ?? []));
    sohFileName = '${backup['sohFileName'] ?? ''}';
    draft = backup['draft'] == null ? null : Audit.fromJson(Map<String, dynamic>.from(backup['draft']));
    activeDraftRackIndex = asInt(backup['activeDraftRackIndex']);
    await save();
  }
}
