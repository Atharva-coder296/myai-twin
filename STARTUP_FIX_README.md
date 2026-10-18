# RetailSAudit startup diagnostic fix

The earlier APK catches exceptions from `store.load()` and `Firebase.initializeApp()` and displays one generic message. This patch adds a stage-specific message and configures the Google Services Android Gradle plugin in Codemagic, which was missing from the build workflow.

Replace repository files with this source and run a fresh Codemagic build. If the new APK still fails, report the `Failed during:` message and, ideally, `RetailSAudit startup failure` lines from Android logcat.

Do not clear app data or uninstall the old APK before backing up local audit data. The fix is untested in Flutter/Codemagic in this environment.
