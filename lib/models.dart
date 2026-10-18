import 'dart:convert';

String newId() => DateTime.now().microsecondsSinceEpoch.toString();
String today() {
  final d = DateTime.now();
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

int asInt(dynamic value, [int fallback = 0]) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? fallback;

class Account {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String role;
  final String salt;
  final String passwordHash;
  bool suspended;
  Account({required this.id, required this.name, required this.email,
    required this.phone, required this.role, required this.salt,
    required this.passwordHash, this.suspended = false});
  bool get isAdmin => role == 'admin';
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'email': email,
    'phone': phone, 'role': role, 'salt': salt, 'passwordHash': passwordHash, 'suspended': suspended};
  factory Account.fromJson(Map<String, dynamic> j) => Account(
    id: '${j['id'] ?? ''}', name: '${j['name'] ?? ''}',
    email: '${j['email'] ?? ''}', phone: '${j['phone'] ?? ''}',
    role: '${j['role'] ?? 'employee'}', salt: '${j['salt'] ?? ''}',
    passwordHash: '${j['passwordHash'] ?? ''}', suspended: j['suspended'] == true);
}

class CountRow {
  String barcode;
  int quantity;
  CountRow({required this.barcode, required this.quantity});
  Map<String, dynamic> toJson() => {'barcode': barcode, 'quantity': quantity};
  factory CountRow.fromJson(Map<String, dynamic> j) => CountRow(
    barcode: '${j['barcode'] ?? ''}', quantity: asInt(j['quantity']));
}

class RackCount {
  final String id;
  String rack;
  String auditor;
  String date;
  List<CountRow> rows;
  RackCount({required this.id, required this.rack, required this.auditor,
    required this.date, List<CountRow>? rows}) : rows = rows ?? [];
  int get units => rows.fold(0, (n, r) => n + r.quantity);
  Map<String, dynamic> toJson() => {'id': id, 'rack': rack, 'auditor': auditor,
    'date': date, 'rows': rows.map((e) => e.toJson()).toList()};
  factory RackCount.fromJson(Map<String, dynamic> j) => RackCount(
    id: '${j['id'] ?? newId()}', rack: '${j['rack'] ?? ''}',
    auditor: '${j['auditor'] ?? ''}', date: '${j['date'] ?? today()}',
    rows: (j['rows'] as List? ?? []).map((e) => CountRow.fromJson(Map<String, dynamic>.from(e))).toList());
  void scan(String barcode) {
    final matches = rows.where((r) => r.barcode == barcode);
    if (matches.isEmpty) {
      rows.add(CountRow(barcode: barcode, quantity: 1));
    } else {
      matches.first.quantity++;
    }
  }
  void editBarcode(int index, String updatedBarcode) {
    if (index < 0 || index >= rows.length) throw RangeError.index(index, rows);
    final row = rows[index];
    if (row.barcode == updatedBarcode) return;
    final existing = rows.where((r) => r.barcode == updatedBarcode);
    if (existing.isNotEmpty) {
      existing.first.quantity += row.quantity;
      rows.removeAt(index);
    } else {
      row.barcode = updatedBarcode;
    }
  }
}

class Audit {
  String id;
  String name;
  String brand;
  String storeCode;
  int eanLength;
  String date;
  bool imported;
  List<RackCount> racks;
  Audit({required this.id, required this.name, required this.brand,
    required this.storeCode, required this.eanLength, required this.date,
    required this.racks, this.imported = false});
  int get units => racks.fold(0, (n, r) => n + r.units);
  Map<String, int> get aggregate {
    final result = <String, int>{};
    for (final rack in racks) {
      for (final row in rack.rows) {
        result[row.barcode] = (result[row.barcode] ?? 0) + row.quantity;
      }
    }
    return result;
  }
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'brand': brand,
    'storeCode': storeCode, 'eanLength': eanLength, 'date': date,
    'imported': imported, 'racks': racks.map((e) => e.toJson()).toList()};
  factory Audit.fromJson(Map<String, dynamic> j) => Audit(
    id: '${j['id'] ?? newId()}', name: '${j['name'] ?? ''}',
    brand: '${j['brand'] ?? ''}', storeCode: '${j['storeCode'] ?? ''}',
    eanLength: asInt(j['eanLength'], 13), date: '${j['date'] ?? today()}',
    imported: j['imported'] == true,
    racks: (j['racks'] as List? ?? []).map((e) => RackCount.fromJson(Map<String, dynamic>.from(e))).toList());
}

class SohRow {
  final String barcode;
  final int stock;
  const SohRow(this.barcode, this.stock);
  Map<String, dynamic> toJson() => {'barcode': barcode, 'stock': stock};
  factory SohRow.fromJson(Map<String, dynamic> j) => SohRow(
      '${j['barcode'] ?? ''}', asInt(j['stock']));
}

class VarianceLine {
  final String barcode;
  final int soh;
  final int physical;
  const VarianceLine(this.barcode, this.soh, this.physical);
  int get difference => physical - soh;
  String get status => difference == 0 ? 'Matched' :
      difference > 0 ? 'Excess' : 'Shortage';
  Map<String, dynamic> toJson() => {'barcode': barcode, 'soh': soh, 'physical': physical};
  factory VarianceLine.fromJson(Map<String, dynamic> j) => VarianceLine(
      '${j['barcode'] ?? ''}', asInt(j['soh']), asInt(j['physical']));
}

class VarianceReport {
  final String id;
  final String auditId;
  final String name;
  final String date;
  final List<VarianceLine> lines;
  const VarianceReport({required this.id, required this.auditId,
    required this.name, required this.date, required this.lines});
  int get mismatchCount => lines.where((r) => r.difference != 0).length;
  Map<String, dynamic> toJson() => {'id': id, 'auditId': auditId, 'name': name,
    'date': date, 'lines': lines.map((e) => e.toJson()).toList()};
  factory VarianceReport.fromJson(Map<String, dynamic> j) => VarianceReport(
    id: '${j['id'] ?? newId()}', auditId: '${j['auditId'] ?? ''}',
    name: '${j['name'] ?? ''}', date: '${j['date'] ?? today()}',
    lines: (j['lines'] as List? ?? []).map((e) => VarianceLine.fromJson(Map<String, dynamic>.from(e))).toList());
}

List<VarianceLine> calculateVariance(Audit audit, Iterable<SohRow> soh) {
  final stock = <String, int>{};
  for (final row in soh) {
    stock[row.barcode] = (stock[row.barcode] ?? 0) + row.stock;
  }
  final physical = audit.aggregate;
  final barcodes = {...stock.keys, ...physical.keys}.toList()..sort();
  return barcodes.map((b) => VarianceLine(b, stock[b] ?? 0, physical[b] ?? 0)).toList();
}

bool validBarcode(String value) => value.trim().isNotEmpty;

String prettyJson(Object? value) => const JsonEncoder.withIndent('  ').convert(value);
