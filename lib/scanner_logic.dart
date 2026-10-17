/// Pure, testable rules for numerical barcode/QR input and EAN mismatches.
/// These rules do not read hardware. A keyboard-wedge HID scanner sends text,
/// and the Flutter scan screen commits a completed value on Enter or idle.
enum EanDecision { acceptOnce, reject, modifyExpectedLength }

class ScanCheck {
  final String value;
  final int expectedLength;
  const ScanCheck(this.value, this.expectedLength);
  bool get isNumeric => RegExp(r'^\d+$').hasMatch(value);
  bool get lengthMatches => value.length == expectedLength;
  bool get needsDecision => isNumeric && !lengthMatches;
}

class ScanOutcome {
  final bool accepted;
  final int expectedLength;
  const ScanOutcome(this.accepted, this.expectedLength);
}

ScanOutcome resolveMismatch(ScanCheck check, EanDecision decision,
    {int? modifiedLength}) {
  if (!check.isNumeric) return ScanOutcome(false, check.expectedLength);
  if (check.lengthMatches) return ScanOutcome(true, check.expectedLength);
  switch (decision) {
    case EanDecision.acceptOnce:
      return ScanOutcome(true, check.expectedLength);
    case EanDecision.reject:
      return ScanOutcome(false, check.expectedLength);
    case EanDecision.modifyExpectedLength:
      if (modifiedLength == null || modifiedLength < 1 || modifiedLength > 128) {
        return ScanOutcome(false, check.expectedLength);
      }
      // Modifying the rule affects future scans only; it rejects the current one.
      return ScanOutcome(false, modifiedLength);
  }
}
