# Firebase configuration status

Verified Firebase project `retailsaudit-dccd8` and Android package `com.retailsaudit.app`. The supplied google-services JSON is copied into the generated Android project during Codemagic builds.

This does NOT deploy Cloud Functions, configure the Google Services Gradle plugin, assign initial admin privileges, verify Firestore rules, or establish that Firebase initialization and login work at runtime. Do not publish or distribute until those are implemented and tested.

The Firebase configuration is a client configuration, not an Admin SDK private key. Never add a service-account key to the mobile app.
