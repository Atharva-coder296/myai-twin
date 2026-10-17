# Firebase registration status

- Firebase project: `retailsaudit-dccd8`
- Android package: `com.retailsaudit.app`; config at `android/app/google-services.json`
- iOS bundle: `com.retailsaudit.app`; config at `ios/Runner/GoogleService-Info.plist`
- Both configs were parsed and checked for matching project identifiers.

## Important unfinished work

This is source/configuration packaging only, **not a compiled app or live Firebase connection**. The project currently lacks generated Flutter Android/iOS platform scaffolding; generate it using `flutter create --platforms=android,ios .` in the project directory (back up configs before generating). Add Firebase dependencies, initialize Firebase in Dart, wire Auth/Firestore, and configure native build files before compiling. iOS requires macOS/Xcode or a compatible cloud build. Do not use this project for production audits until authorization, data access rules, persistence and hardware tests are completed.
