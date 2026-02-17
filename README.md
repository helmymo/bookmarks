# Universal Bookmarks - Premium Flutter App

A beautiful, premium bookmark manager app built with Flutter that allows you to save, organize, and preview links from any app.

![Flutter](https://img.shields.io/badge/Flutter-3.x-blue)
![License](https://img.shields.io/badge/license-MIT-green)

## ✨ Features

### Premium Design
- 🎨 Glassmorphism UI with backdrop blur effects
- 🌙 Dark theme with gradient colors (indigo/purple/pink)
- ✨ Smooth animations and transitions
- 📱 Beautiful shimmer loading effects

### Core Functionality
- 🔗 Save links by sharing from any app
- 🔍 Real-time search filtering
- 📂 Category/folder organization
- 💾 Persistent local storage
- 🔄 Backup and restore (JSON export/import)

### Categories
- Uncategorized
- Work
- Personal
- Shopping
- News
- Entertainment
- Custom categories (create your own!)

## 🚀 Getting Started

### Prerequisites
- Flutter SDK 3.x
- Android SDK (for Android builds)
- Xcode (for iOS builds)
- Git

### Installation

1. Clone the repository:
```bash
git clone <your-repo-url>
cd universal_bookmarks
```

2. Install dependencies:
```bash
flutter pub get
```

3. Run the app:
```bash
flutter run
```

### Building

#### Android
```bash
# Debug APK
flutter build apk --debug

# Release APK
flutter build apk --release
```

#### iOS (requires macOS)
```bash
# For Simulator
flutter build ios --simulator --no-codesign

# For Device (requires Apple Developer account)
flutter build ios --release
```

## 📁 Project Structure

```
lib/
├── main.dart                    # App entry point
├── screens/
│   └── home_screen.dart         # Main screen UI
└── services/
    ├── bookmark_storage.dart     # Local storage service
    └── share_service.dart        # Share intent handling
```

## 🤖 GitHub Actions CI/CD

The project includes automated CI/CD workflows for building both Android and iOS apps.

### iOS Build Workflow
The iOS build runs on macOS and builds the app for the iOS simulator.

**To use:**
1. Push your code to GitHub
2. Go to Actions tab
3. Run the "Build iOS App" workflow

### Workflow Features:
- Runs on latest macOS
- Installs Flutter stable
- Builds iOS simulator app
- Uploads build artifact

## 📱 Screenshots

The app features:
- Premium dark gradient background
- Glassmorphism app bar
- Animated bookmark cards
- Color-coded category indicators
- Swipe-to-delete functionality

## 📄 License

This project is licensed under the MIT License.

## 🙏 Acknowledgments

- [Flutter](https://flutter.dev)
- [any_link_preview](https://pub.dev/packages/any_link_preview)
- [shimmer](https://pub.dev/packages/shimmer)
- [flutter_staggered_animations](https://pub.dev/packages/flutter_staggered_animations)
