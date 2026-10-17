# RetailSAudit — Flutter Android + iOS project

**For The Retail Audit & Allied Services**

This is the **first working Flutter source-code MVP** of RetailSAudit, built to
replace the earlier HTML prototype. It is **not** a published Android/iOS app,
and the local account system is for **testing, not real employee deployment**.

## What the Flutter MVP implements

- First-run setup for the primary admin ID `RetailSAudit`, email
  `retailsaudit@gmail.com`. **You create the password yourself inside the app**.
  The password is never embedded in any source file. On-device demo accounts
  use salted PBKDF2 hashes, but these accounts are **not centrally authenticated**.
- Admin-only **Add User** (Registration / Add an Admin); employees cannot see it.
- Import a location barcode list from CSV/XLSX.
- Upload/replace an SOH (Stock on Hand) file from CSV/XLSX.
- Start an audit: company/brand, store code, EAN length, auditor, date, rack.
- 2D keyboard-wedge scanner accepts **both barcodes and QR codes containing
  numeric product IDs**, without a separate camera scanner or QR screen.
- After scan input completes: count duplicates only within the current rack,
  **save every accepted scan**, show inventory rows. Scans are committed on
  Enter or 650 ms of inactivity. A visible scan field avoids losing scanner focus.
- On EAN mismatch: **blocking in-app dialog** Yes (one product), No (reject),
  Modify Expected Length (future scans; current code rejected). Sound preference
  triggers 3 system alerts if the phone supports them.
- Add additional locations under the same audit; choose same/new auditor.
- Resume unfinished audit, end and name, open report, edit a selected rack.
- Import an external audit report (CSV/XLSX) into the Saved Audit Reports list.
- Create variance (Physical − SOH), aggregated across racks only for variance.
- Export/share XLSX audit, SOH and variance reports, **including sharing all
  three in one device share-sheet action**.
- Selective deletion of one saved audit, variance report, SOH, or location list.
- Settings: profile, scanner diagnostics, backup export/restore, report history,
  theme, text size, sounds, admin emails, version, privacy information.

## Important limitations — do not use as a production deployment yet

1. Accounts are **local to each device** and are not validated by a central
   server. A fresh installation can create a new primary admin. Backend-auth
   and server-enforced roles are required before company rollout.
2. Audit data is stored using `shared_preferences` on the current device only.
   This is a demo storage layer; production needs encrypted local database,
   cloud synchronization and off-device backups.
3. **No automatic emails are sent.** Sharing opens the phone's native
   share/email UI. The Firebase server starter in `firebase/` is not connected.
4. No actual Play Store / App Store build artifacts are included. App signing,
   store accounts and platform toolchains are required.
5. Only CSV and **XLSX** imports are supported. Legacy `.xls` files should be
   converted to `.xlsx` first. Preserve barcodes as **text** in spreadsheets
   to keep leading zeros.
6. System alert sounds depend on device settings, and physical scanner behavior
   must be verified on Android and iPhone. Some Bluetooth scanners require
   keyboard/HID mode and an Enter suffix.
7. Editing existing reports does not email edits until the backend is wired.
8. This source has been statically inspected, but **cannot be compiled or run
   in this environment because Flutter and Android/iOS SDKs are unavailable**.
   Run `flutter analyze` and `flutter test` locally before release.

## Set up on a Mac (Android and iPhone)

1. Install **Flutter SDK**, **Xcode** (for iOS), and **Android Studio**.
   Follow the official Flutter installation instructions:
   https://docs.flutter.dev/get-started/install
2. Open Terminal and go into this downloaded project folder:

   ```bash
   cd ~/Downloads/RetailSAudit_Flutter
   flutter doctor
   flutter create --project-name retailsaudit --platforms=android,ios .
   flutter pub get
   flutter analyze
   flutter test
   ```

   `flutter create` generates the standard native Android and iOS platform
   folders, which are **not included** in this source archive.

3. Connect an Android phone with USB debugging enabled, or an iPhone configured
   for development in Xcode. From the same folder:

   ```bash
   flutter devices
   flutter run
   ```

4. On first launch, choose a **fresh** password for the primary admin.
   Use ID `RetailSAudit` to sign in. Do not reuse a password you shared in chat.
5. Test with a real HID scanner: a 13-digit barcode, a numeric QR containing
   the same number, a shorter barcode (Yes/No/Modify), consecutive rapid scans,
   different racks and exported spreadsheets.

## Production roadmap

**Phase 1 — Local MVP:** Flutter UI, scans, racks, imports/exports, variance,
settings (the code in this archive).

**Phase 2 — Secure backend:** Firebase Auth, Firestore, Storage, secure user
provisioning, per-role server authorization, cloud auditing and off-device backup.
The `firebase/` folder provides backend starting files only. The Flutter MVP
**is not yet integrated** with them.

**Phase 3 — Report delivery:** generate final XLSX files, upload a validated
report bundle, call a secure mail service from the backend, send Audit + SOH +
Variance attachments **from and to `retailsaudit@gmail.com`** and record status.
Never store an SMTP password or Gmail token in the Flutter app.

**Phase 4 — Release:** run automated + physical-scanner tests, privacy and
security review, configure signing, submit Android App Bundle through Google
Play Console and iOS build through App Store Connect/TestFlight.

## File structure

- `lib/main.dart` — Material app, themes, routing foundation
- `lib/models.dart` — audits, racks, quantities, SOH and variance calculation
- `lib/store.dart` — local persistence and testing accounts
- `lib/services/files.dart` — CSV/XLSX imports, Excel exports, share/backup
- `lib/screens/auth.dart` — first-run primary admin and login
- `lib/screens/dashboard.dart` — dashboard/navigation
- `lib/screens/audit.dart` — initial audit details and physical scanner
- `lib/screens/upload.dart` — Upload Data and admin registration
- `lib/screens/reports.dart` — saved audit, SOH, variance, selective deletion
- `lib/screens/settings.dart` — settings, diagnostics, backup and about
- `test/models_test.dart` — logic tests
- `firebase/` — **unconnected** secure server starter

## Primary admin and email details

- Display/login ID: **RetailSAudit**
- Primary admin email: **retailsaudit@gmail.com**
- Intended automatic sender and recipient: **retailsaudit@gmail.com**
- **Admin password: set privately in the app during first-run setup**.

The same email address can be used as both sender and recipient after approved
server-side Gmail authentication is configured.
