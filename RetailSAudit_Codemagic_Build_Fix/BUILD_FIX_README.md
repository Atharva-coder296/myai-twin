# Fix for Codemagic "deleted Android v1 embedding"

The earlier RetailSAudit source archive did not contain a complete Flutter Android/iOS platform scaffold. Codemagic's automatic Android build therefore failed with an obsolete-embedding detection error. This revision adds `codemagic.yaml`, which creates modern Android and iOS scaffolding on the remote Codemagic build machine before compiling.

1. Add `codemagic.yaml` to the ROOT of the GitHub repository (beside `pubspec.yaml`).
2. In Codemagic Workflow Editor, click **Switch to YAML configuration** and choose `retailsaudit-android-debug`.
3. Run a manual build on `main`.

The build will run `flutter analyze` and `flutter test` before building. If either fails, the log will show the next source issue to fix. No success is guaranteed until Codemagic runs this workflow.

The Android/iOS Firebase configuration files are included, but Firebase Auth/Firestore are not yet wired into the Dart application. Do not use this development build for real business data.
