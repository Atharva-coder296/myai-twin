import 'package:flutter_test/flutter_test.dart';
import 'package:retailsaudit/models.dart';

void main() {
  group('barcode input', () {
    test('barcode and QR payloads support nonempty numeric and text values', () {
      expect(validBarcode('8901808000068'), isTrue);
      expect(validBarcode('https://example.com'), isTrue);
      expect(validBarcode('SKU-A123'), isTrue);
      expect(validBarcode('   '), isFalse);
      expect(validBarcode('0012345678901'), isTrue);
    });
  });
  group('location counts', () {
    test('scans in different racks remain independent', () {
      final a = Audit(id: '1', name: 'Test', brand: 'Brand', storeCode: 'S1',
        eanLength: 13, date: '2026-10-17', racks: [
          RackCount(id: 'r1', rack: 'Rack 1', auditor: 'A', date: '2026-10-17'),
          RackCount(id: 'r2', rack: 'Rack 2', auditor: 'A', date: '2026-10-17'),
        ]);
      a.racks[0].scan('8901808000068');
      a.racks[0].scan('8901808000068');
      a.racks[1].scan('8901808000068');
      expect(a.racks[0].units, 2);
      expect(a.racks[1].units, 1);
      expect(a.aggregate['8901808000068'], 3);
    });
    test('editing to existing barcode merges rows in same rack', () {
      final r = RackCount(id: '1', rack: 'R', auditor: 'A', date: today(), rows: [
        CountRow(barcode: '111', quantity: 2),
        CountRow(barcode: '222', quantity: 3),
      ]);
      r.editBarcode(1, '111');
      expect(r.rows, hasLength(1));
      expect(r.rows.first.quantity, 5);
    });
  });
  group('variance report', () {
    test('includes codes absent in physical inventory and SOH', () {
      final a = Audit(id: '1', name: 'A', brand: '', storeCode: '',
        eanLength: 13, date: today(), racks: [
          RackCount(id: 'r', rack: 'R', auditor: 'A', date: today(), rows: [
            CountRow(barcode: '111', quantity: 4),
            CountRow(barcode: '333', quantity: 2),
          ])]);
      final lines = calculateVariance(a, [const SohRow('111', 7), const SohRow('222', 5)]);
      expect(lines, hasLength(3));
      expect(lines.firstWhere((v) => v.barcode == '111').difference, -3);
      expect(lines.firstWhere((v) => v.barcode == '222').difference, -5);
      expect(lines.firstWhere((v) => v.barcode == '333').difference, 2);
    });
    test('json roundtrip preserves leading zeros', () {
      final a = Audit(id: '1', name: 'Test', brand: 'B', storeCode: 'S',
        eanLength: 13, date: today(), racks: [
          RackCount(id: 'r', rack: '1', auditor: 'A', date: today(), rows: [
            CountRow(barcode: '0012345678901', quantity: 1)])]);
      expect(Audit.fromJson(a.toJson()).racks.first.rows.first.barcode, '0012345678901');
    });
  });
}
