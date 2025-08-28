# Storage Cleaner App

A Flutter application to help clean and manage device storage on Android.

## Project Structure

This app is built with Flutter using Material 3 design with a soft blue/purple gradient theme and supports both light and dark modes.

### Screens

- **OnboardingScreen**: Introduction slides for first-time users
- **HomeScreen**: Main screen showing storage usage and available actions
- **ScanScreen**: Screen that shows scanning animation and progress
- **ResultsScreen**: Shows scan results and files that can be cleaned
- **CleanerSuccessScreen**: Success screen shown after cleaning
- **SettingsScreen**: App settings including dark mode toggle

### Navigation

The app uses Navigator 2.0 with named routes for screen navigation.

## Getting Started

1. Ensure you have Flutter installed
2. Clone this repository
3. Run `flutter pub get` to install dependencies
4. Run `flutter run` to launch the app on a connected device or emulator

## Current Status

This is a basic scaffold of the app with empty screen placeholders and navigation. No actual functionality has been implemented yet.

## Future Development

- Add actual storage scanning functionality
- Implement file categorization and selection
- Add cleanup animation and success metrics
- Implement device storage API integration
