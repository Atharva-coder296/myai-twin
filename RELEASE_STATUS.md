# RetailSAudit 2.0 — stabilization source (NOT A RELEASE APK)

Preserves the original logo and name. Adds a non-red fallback UI for Flutter widget errors and a startup retry screen. Updates scanner tests for alphanumeric barcodes. Earlier development changes include camera scanning and backend scaffolding.

**Not guaranteed crash-free:** Android native crashes, plugin failures, missing Firebase configuration, and build errors require device/build logs and testing.

**Cloud status:** Firebase authentication is not connected to the live sign-in UI; account creation, multi-device login, presence and remote suspension are not end-to-end functional. A Firebase project, configuration, backend deployment and testing are required.

**HHT status:** keyboard-wedge scanners are the initial path; proprietary SDK support is not universal.

**Build:** Upload the project contents to the GitHub repository root and use Codemagic. Flutter SDK is not installed in this working environment, so this archive has not been Flutter-compiled or device-tested.

Do not replace the currently working APK until a new APK passes real-device tests and saved data migration checks.
