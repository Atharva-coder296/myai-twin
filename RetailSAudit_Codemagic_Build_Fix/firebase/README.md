# Firebase server starter — NOT YET DEPLOYED

The Flutter MVP in `../lib` is currently a local-only app. These server files are
scaffolding for the production upgrade, **not an active integration**.

1. Create a Firebase project in your own Google account and enable Billing if
   required for Cloud Functions, Firebase Authentication (Email/Password),
   Firestore, and Cloud Storage.
2. Install Firebase CLI / FlutterFire CLI and register Android and iOS apps.
3. Create the primary admin via Firebase Authentication in the console; choose a
   **new** password directly there. Never send credentials over chat or commit them.
4. Seed `users/{firebaseUid}` with a trusted Admin SDK operation (NOT client-side):
   `{id: "RetailSAudit", email: "retailsaudit@gmail.com", role: "admin", active: true,
     orgId: "retailsaudit"}`. Add employees with `role: employee` and the same org.
5. Audit the Firestore and Storage rules against your real company requirements.
6. For this example email function, set the Gmail app password from your own
   terminal using `firebase functions:secrets:set GMAIL_APP_PASSWORD`. Gmail may
   not offer app passwords for every account; an approved email API/provider is
   preferable for production.
7. Deploy with `firebase deploy --only functions,firestore:rules,storage`.
8. **Still required:** Wire the Flutter app to Firebase Auth/Firestore/Storage and
   the callable function. The local MVP does not invoke `emailThreeReports`.

The Cloud Function checks the user's organization, validates three report files,
and sends them from and to `retailsaudit@gmail.com`. This is a starting point,
not a deployment-ready company mail system; a production version should include
retries, rate limiting, monitoring, user role tests and an audited delivery queue.
