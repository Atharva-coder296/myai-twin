import 'package:flutter_test/flutter_test.dart';
import 'package:retailsaudit/scanner_logic.dart';

void main() {
  test('13-digit barcode/QR passes without mismatch dialog', () {
    final check = ScanCheck('8901808000068', 13);
    expect(check.isNumeric, true);
    expect(check.lengthMatches, true);
    expect(check.needsDecision, false);
  });

  test('different EAN length must ask for Yes/No/Modify', () {
    final check = ScanCheck('123456789012', 13);
    expect(check.needsDecision, true);
    expect(resolveMismatch(check, EanDecision.acceptOnce).accepted, true);
    expect(resolveMismatch(check, EanDecision.acceptOnce).expectedLength, 13);
    expect(resolveMismatch(check, EanDecision.reject).accepted, false);
    expect(resolveMismatch(check, EanDecision.reject).expectedLength, 13);
  });

  test('Modify changes the expected length but rejects current scan', () {
    final check = ScanCheck('123456789012', 13);
    final outcome = resolveMismatch(check, EanDecision.modifyExpectedLength,
        modifiedLength: 12);
    expect(outcome.accepted, false);
    expect(outcome.expectedLength, 12);
    expect(ScanCheck('123456789012', outcome.expectedLength).needsDecision, false);
  });

  test('Nonempty alphanumeric codes are supported and checked for length', () {
    final check = ScanCheck('https://example.com', 13);
    expect(check.isNumeric, true);
    expect(check.needsDecision, true);
    expect(resolveMismatch(check, EanDecision.acceptOnce).accepted, true);
  });
}
