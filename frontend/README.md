# Reward Hub App - Frontend

This is the Flutter frontend for the Reward Hub App.

## Setup Instructions

1. Ensure you have the Flutter SDK installed.
2. Navigate to the `frontend/` directory.
3. Run `flutter pub get` to install dependencies.
4. Set up Firebase for your project:
   - Ensure you have the Firebase CLI installed and configured.
   - Run `flutterfire configure` to generate the `firebase_options.dart` file (if applicable) and connect to your Firebase project. Note that `lib/main.dart` currently initializes Firebase using `Firebase.initializeApp()` with default options, so you may need to pass `options: DefaultFirebaseOptions.currentPlatform` if configuring for multiple platforms.
5. Run the app using `flutter run`.

## Notes
- This frontend reads from the `campaigns` collection in Firestore.
- It displays a list of campaigns showing `title`, `storeName`, and `details`.
