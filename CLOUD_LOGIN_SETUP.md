# Cloud login integration — deployment required

The Flutter login screen now authenticates against Firebase Authentication, and the admin employee-management screen invokes protected Firebase callable functions. Local prototype credentials are no longer accepted for sign-in.

## Required before building and using
1. Create or select your Firebase project. Enable Authentication > Email/Password, Firestore, and Cloud Functions with billing as required.
2. Provision the first administrator using Firebase Console: create a Firebase Auth email/password user; create `users/{uid}` in Firestore with `id`, `name`, `email`, `role: admin`, `active: true`, and `orgId: retailsaudit`. Never bootstrap admin privileges from the phone.
3. Configure Android Firebase for package `com.retailsaudit.app` (verify actual applicationId in generated Gradle file). Supply correct `google-services.json`, Google Services Gradle plugin, or generated `firebase_options.dart` via FlutterFire CLI and initialize with the options. The current source calls `Firebase.initializeApp()` and requires working native configuration.
4. Deploy `firebase/firestore.rules` and `firebase/functions` with Firebase CLI, after reviewing billing, region and organization settings.
5. Test employee creation, sign-in on two devices, and suspension on both devices. Test offline behavior and token revocation: the Firestore active flag prevents protected data access, but automatic device sign-out requires connectivity and successful profile listener updates.
6. The employee list currently shows **account status**, not actual live device presence. A proper presence heartbeat and server-managed session list remain necessary.

IMPORTANT: No Firebase project was provisioned or deployed here. The ZIP is not a ready-to-use cloud service. The pre-existing local audit storage remains per-device; it is not automatically synced between devices.
