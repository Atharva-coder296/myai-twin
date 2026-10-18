# RetailSAudit Spark-only setup

No Cloud Functions or Blaze plan required. This project uses Firebase Authentication and Firestore.

## 1. Bootstrap the first admin (trusted Firebase Console only)

1. Firebase Authentication > Users: locate the existing admin account and copy its UID.
2. Firestore > `users` > create document with **document ID equal to the admin Auth UID**.
3. Add fields: `active` (boolean `true`), `role` (string `admin`), `orgId` (string `retailsaudit`), `name` (string), `id` (string).
4. Firestore > Rules: publish `firebase/firestore.rules` from this package. Do not deploy the previous allow-all or deny-all rules.
5. Verify that the admin can log in and view Employees.

## 2. Provision each employee (trusted Firebase Console only)

1. Authentication > Users > Add user: create email `employeeid@staff.retailsaudit.invalid` and a strong permanent password; save it securely and share privately with the employee.
2. Copy that account's Auth UID.
3. Firestore > `users` > create document with ID = Auth UID, fields: `active` (boolean true), `role` (string `employee`), `orgId` (string `retailsaudit`), `name` (string), `id` (string employeeid).
4. Employee logs in using employee ID and assigned password. Do not let employees self-register.

**Limitation:** Firebase Console is required for employee creation and password resets on Spark. The app's Admin screen can list and suspend/reactivate employee profiles but cannot safely create Auth accounts or reset passwords without a trusted backend. Suspension denies Firestore access but does not disable the Firebase Auth identity or instantly erase offline data. Admin must disable the Auth user manually in Firebase Console for hard revocation.

## 3. Build and validate

Use the top-level project directory. Run `flutter pub get`, `flutter analyze`, `flutter test`, and a Codemagic Android build. Check Gradle Google Services integration. This package was not compiled or deployed here.
