# RetailSAudit Spark employee registration

The Admin > Upload Data > Add User screen and Employees > Add User screen now open the same Employee Registration form: name, email, phone, employee ID, password.

Registration creates a Firebase Authentication email/password user using a secondary Firebase app (so the administrator remains signed in), then writes users/{newUid} in Firestore. The password is sent to Firebase Auth and is NOT stored in Firestore. The employee signs in with EMAIL + password. The ID is a staff identifier, not an alternate login credential.

## REQUIRED FIREBASE CHANGE

The Firestore rules already published in the console only accept five fields on user creation. Replace the deployed rules with firebase/firestore.rules from this ZIP, which accepts email and phone as well. Test before production use.

## SECURITY LIMITATION (IMPORTANT)

Firebase Authentication's client-side sign-up endpoint is public when email/password sign-up is enabled. Firestore rules protect employee profiles and inventory data, but cannot prevent unauthenticated users from creating unapproved Firebase Auth identities. These identities receive NO profile and NO Firestore access. For strict admin-only Auth provisioning, a trusted server/Admin SDK or manual Firebase Console provisioning is required. Never ship Admin SDK service-account credentials in the APK.

The Firebase Authentication email/password provider must remain enabled. Registration requires internet access. Failed Firestore writes attempt to delete the newly created Auth identity; if cleanup fails, an orphaned Auth user may need removal from Firebase Console. Registration is not atomic across Auth and Firestore.

Do not release without emulator tests for role escalation, suspension, cross-organization access, duplicate staff IDs under concurrency, and actual APK compilation. Firestore queries alone do not guarantee a globally unique employee ID under simultaneous registration.
