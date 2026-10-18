# RetailSAudit 2.0 — Cloud integration (not activated)

The cloud backend is a secure foundation, NOT a live multi-device login feature yet.

1. Create and configure a Firebase project. Enable Email/Password authentication,
   Firestore, and Cloud Functions (billing may be required).
2. Provision the first administrator in Firebase Auth and manually create a
   `users/{uid}` document with `role: admin`, `active: true`, `orgId: retailsaudit`.
   Use a verified real email for the administrator.
3. Deploy `firebase/firestore.rules` and `firebase/functions` to the same project.
4. Add FlutterFire platform configuration, initialize Firebase before using
   `CloudAccounts`, and replace the local-demo authentication screens.
5. Add authenticated presence heartbeats per device/session and admin UI;
   presence is NOT implemented in this source package.
6. Test revocation, simultaneous sign-ins, offline behavior, Firestore rules,
   and permissions before rollout. Disabling an Auth account blocks new sign-ins;
   security rules must also check `active` to stop existing tokens accessing data.
7. Auth email aliases ending in `.invalid` are internal usernames, not inboxes.
   Password recovery must be admin-managed; do not send recovery mail there.

Current release is a DEVELOPMENT SOURCE ONLY. No APK was compiled.
