import 'dart:convert';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models.dart';
import '../store.dart';

class ImportFile {
  final String name;
  final List<List<String>> rows;
  ImportFile(this.name, this.rows);
}

class AuditFiles {
  static Future<ImportFile?> pickTable() async {
    final selection = await FilePicker.platform.pickFiles(
      type: FileType.custom, allowedExtensions: ['csv', 'xlsx'], withData: true);
    if (selection == null || selection.files.isEmpty) return null;
    final chosen = selection.files.single;
    final data = chosen.bytes ?? (chosen.path == null ? null : await File(chosen.path!).readAsBytes());
    if (data == null) throw FormatException('Unable to read this file');
    if (chosen.name.toLowerCase().endsWith('.csv')) {
      final text = utf8.decode(data, allowMalformed: true).replaceFirst('\uFEFF', '');
      final csvRows = const CsvToListConverter(shouldParseNumbers: false).convert(text);
      return ImportFile(chosen.name, csvRows.map((r) => r.map((c) => '$c').toList()).toList());
    }
    final book = Excel.decodeBytes(data);
    if (book.tables.isEmpty) throw FormatException('No worksheets were found');
    // Pick the first sheet with nonempty rows, not an empty default sheet.
    final sheets = book.tables.values.toList();
    final sheet = sheets.firstWhere((s) =>
      s.rows.any((row) => row.any((cell) => cell?.value != null)),
      orElse: () => sheets.first);
    final rows = sheet.rows.map((row) => row.map((cell) => _cellString(cell?.value)).toList()).toList();
    return ImportFile(chosen.name, rows);
  }

  static String _cellString(CellValue? value) {
    if (value == null) return '';
    if (value is TextCellValue) return value.value.toString();
    if (value is IntCellValue) return value.value.toString();
    if (value is DoubleCellValue) {
      final v = value.value;
      return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
    }
    if (value is BoolCellValue) return '${value.value}';
    return value.toString();
  }

  static List<List<String>> _clean(ImportFile file) => file.rows
      .where((row) => row.any((cell) => cell.trim().isNotEmpty))
      .map((row) => row.map((e) => e.trim()).toList()).toList();

  static int _column(List<String> names, List<String> aliases) =>
      names.indexWhere((n) => aliases.any((alias) => n.contains(alias)));

  static List<SohRow> parseSoh(ImportFile file) {
    final rows = _clean(file);
    if (rows.isEmpty) throw FormatException('SOH file is empty');
    final header = rows.first.map((e) => e.toLowerCase()).toList();
    var barcodeIndex = _column(header, ['barcode', 'ean', 'sku', 'product code']);
    var stockIndex = _column(header, ['soh', 'stock on hand', 'system stock', 'stock', 'quantity', 'qty']);
    if (barcodeIndex < 0 || stockIndex < 0) {
      throw FormatException('SOH needs Barcode and Stock/Quantity column headings');
    }
    final result = <String, int>{};
    for (final row in rows.skip(1)) {
      if (row.length <= barcodeIndex || row.length <= stockIndex) continue;
      final barcode = row[barcodeIndex];
      final stock = int.tryParse(row[stockIndex]);
      if (!validBarcode(barcode) || stock == null || stock < 0) continue;
      result[barcode] = (result[barcode] ?? 0) + stock;
    }
    if (result.isEmpty) throw FormatException('No valid SOH rows found');
    return result.entries.map((e) => SohRow(e.key, e.value)).toList();
  }

  static List<String> parseLocations(ImportFile file) {
    final rows = _clean(file);
    if (rows.isEmpty) throw FormatException('Location file is empty');
    final first = rows.first.first.toLowerCase();
    final start = (first.contains('location') || first.contains('rack') || first.contains('barcode')) ? 1 : 0;
    final codes = <String>{};
    for (final row in rows.skip(start)) {
      if (row.isNotEmpty && row.first.isNotEmpty) codes.add(row.first);
    }
    if (codes.isEmpty) throw FormatException('No location codes found');
    return codes.toList();
  }

  static Audit parseAudit(ImportFile file) {
    final rows = _clean(file);
    if (rows.isEmpty) throw FormatException('Audit file is empty');
    final h = rows.first.map((e) => e.toLowerCase()).toList();
    final codeCol = _column(h, ['barcode', 'ean', 'product code', 'sku']);
    final qtyCol = _column(h, ['quantity', 'qty', 'physical', 'count']);
    final rackCol = _column(h, ['location', 'rack']);
    final auditorCol = _column(h, ['auditor']);
    final brandCol = _column(h, ['brand', 'company']);
    final storeCol = _column(h, ['store']);
    if (codeCol < 0 || qtyCol < 0) {
      throw FormatException('Audit file needs Barcode and Quantity columns');
    }
    final racks = <String, RackCount>{};
    String brand = '', storeCode = '';
    for (final row in rows.skip(1)) {
      final code = codeCol < row.length ? row[codeCol] : '';
      final quantity = qtyCol < row.length ? int.tryParse(row[qtyCol]) : null;
      if (!validBarcode(code) || quantity == null || quantity < 0) continue;
      final rackName = rackCol >= 0 && rackCol < row.length && row[rackCol].isNotEmpty
          ? row[rackCol] : 'Imported Location';
      final auditor = auditorCol >= 0 && auditorCol < row.length ? row[auditorCol] : 'External Auditor';
      if (brandCol >= 0 && brandCol < row.length) brand = row[brandCol];
      if (storeCol >= 0 && storeCol < row.length) storeCode = row[storeCol];
      final groupKey = '$rackName\u0000$auditor';
      final rack = racks.putIfAbsent(groupKey, () => RackCount(id: newId(),
          rack: rackName, auditor: auditor, date: today()));
      final existing = rack.rows.where((r) => r.barcode == code);
      if (existing.isEmpty) {
        rack.rows.add(CountRow(barcode: code, quantity: quantity));
      } else {
        existing.first.quantity += quantity;
      }
    }
    if (racks.isEmpty) throw FormatException('No valid audit entries found');
    return Audit(id: newId(), name: file.name.replaceFirst(RegExp(r'\.(csv|xlsx)$', caseSensitive: false), ''),
      brand: brand, storeCode: storeCode, eanLength: 13, date: today(),
      imported: true, racks: racks.values.toList());
  }

  static String safeName(String raw) => raw.replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_');

  static Future<File> _createXlsx(String filename, List<String> headers, List<List<Object>> rows) async {
    final workbook = Excel.createExcel();
    final sheet = workbook['Report'];
    void append(List<Object> data) {
      sheet.appendRow(data.map<CellValue>((v) => v is num
          ? IntCellValue(v.toInt()) : TextCellValue('$v')).toList());
    }
    append(headers);
    for (final row in rows) { append(row); }
    final bytes = workbook.encode();
    if (bytes == null) throw StateError('Unable to create Excel report');
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${safeName(filename)}.xlsx');
    return file.writeAsBytes(bytes, flush: true);
  }

  static Future<File> auditExcel(Audit audit) async {
    final rows = <List<Object>>[];
    for (final rack in audit.racks) {
      for (final row in rack.rows) {
        rows.add([audit.brand, audit.storeCode, rack.auditor, rack.date,
          rack.rack, row.barcode, row.quantity]);
      }
    }
    return _createXlsx('Audit_${audit.name}',
      ['Company / Brand', 'Store Code', 'Auditor', 'Date', 'Rack Location',
       'Product Barcode / QR Number', 'Quantity'], rows);
  }

  static Future<File> sohExcel(RetailStore store) => _createXlsx('SOH_Report',
      ['Product Barcode', 'System Stock (SOH)'],
      store.soh.map((r) => <Object>[r.barcode, r.stock]).toList());

  static Future<File> varianceExcel(VarianceReport report) => _createXlsx(
      'Variance_${report.name}',
      ['Product Barcode', 'SOH', 'Physical Count', 'Difference (Physical - SOH)', 'Status'],
      report.lines.map((r) => <Object>[
        r.barcode, r.soh, r.physical, r.difference, r.status]).toList());

  static Future<void> shareFile(File file) async =>
      Share.shareXFiles([XFile(file.path)], text: 'RetailSAudit report');

  static Future<void> shareAllThree({required Audit audit,
    required RetailStore store, required VarianceReport variance}) async {
    final files = await Future.wait([auditExcel(audit), sohExcel(store), varianceExcel(variance)]);
    await Share.shareXFiles(files.map((f) => XFile(f.path)).toList(),
        text: 'RetailSAudit: Audit, SOH and Variance Reports');
  }

  static Future<void> shareBackup(RetailStore store) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/RetailSAudit_Backup_${today()}.json');
    // Do not export password hashes / employee credentials in transferable backups.
    final backup = Map<String, dynamic>.from(store.snapshot());
    backup['accounts'] = [];
    await file.writeAsString(prettyJson(backup), flush: true);
    await Share.shareXFiles([XFile(file.path)], text: 'RetailSAudit local data backup');
  }

  static Future<Map<String, dynamic>?> pickBackup() async {
    final selection = await FilePicker.platform.pickFiles(type: FileType.custom,
        allowedExtensions: ['json'], withData: true);
    if (selection == null || selection.files.isEmpty) return null;
    final chosen = selection.files.single;
    final bytes = chosen.bytes ?? (chosen.path == null ? null : await File(chosen.path!).readAsBytes());
    if (bytes == null) throw FormatException('Cannot read backup');
    return Map<String, dynamic>.from(jsonDecode(utf8.decode(bytes)));
  }
}
