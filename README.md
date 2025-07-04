
# date

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Firebase Setup

This project uses Firebase Authentication. Before running the app make sure Firebase is configured:

1. Add a Firebase project and register your Android/iOS apps.
2. Download the `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) files and place them in their respective platform directories.
3. Run `flutterfire configure` if using FlutterFire CLI to generate `firebase_options.dart`.
4. Ensure `Firebase.initializeApp()` is called in `main.dart` before using any Firebase services.

With Firebase configured you can sign in and register users with email and password.
