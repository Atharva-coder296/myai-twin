"""Offline structural audit; NOT a replacement for flutter analyze/flutter test."""
from pathlib import Path
import re
root = Path(__file__).resolve().parent.parent
files = {p.relative_to(root).as_posix(): p.read_text() for p in root.rglob('*.dart')}
checks = {
    'main app entry point': ('lib/main.dart', 'runApp(RetailSAuditApp(store: store))'),
    'first-run admin id': ('lib/store.dart', "static const primaryAdminId = 'RetailSAudit'"),
    'primary report email': ('lib/store.dart', "static const primaryAdminEmail = 'retailsaudit@gmail.com'"),
    'salted password derivation': ('lib/store.dart', 'Pbkdf2('),
    'admin access checks': ('lib/store.dart', "if (!isAdmin) throw StateError('Administrator access required')"),
    'scan auto-save': ('lib/store.dart', 'await save(); // Always auto-save each scan'),
    'mismatch modal': ('lib/screens/audit.dart', 'barrierDismissible: false'),
    'yes mismatch option': ('lib/screens/audit.dart', 'Yes — This Product Only'),
    'no mismatch option': ('lib/screens/audit.dart', 'No — Reject'),
    'modify mismatch option': ('lib/screens/audit.dart', 'Modify EAN Length'),
    'scan input clearing': ('lib/screens/audit.dart', 'scanInput.clear();'),
    'scanner input timeout': ('lib/screens/audit.dart', 'Duration(milliseconds: 650)'),
    'QR numeric same as barcode': ('lib/screens/audit.dart', 'QR/barcode must contain a numeric product ID'),
    'manual barcode fallback': ('lib/screens/audit.dart', 'Type a barcode manually'),
    'saved audit upload': ('lib/screens/reports.dart', 'Upload Audit Report'),
    'variance report': ('lib/screens/reports.dart', 'Generate Variance Report'),
    'all-three export': ('lib/services/files.dart', 'shareAllThree'),
    'selective delete': ('lib/screens/reports.dart', 'Delete Selected File'),
    'backup export': ('lib/services/files.dart', 'shareBackup'),
    'storage rules': ('firebase/storage.rules', 'report-bundles'),
    'backend email sender': ('firebase/functions/index.js', "const REPORT_ADDRESS = 'retailsaudit@gmail.com'"),
}
for name, (path, expected) in checks.items():
    assert expected in (root / path).read_text(), f'MISSING: {name} ({path})'
    print('PASS', name)
assert all('Biba958' not in text for text in files.values()), 'Secret from conversation embedded!'
assert not re.search(r'password\s*=\s*[\'\"]Biba', '\n'.join(files.values()))
print('PASS no shared password embedded in Dart sources')
print(f'{len(checks) + 1} static structural checks passed; app NOT compiled')
