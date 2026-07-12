# Focus Guard — Phone Addiction Controller

A personal-use Flutter application for Android that locks you into a **Focus Mode** where only selected applications are usable. Built with Material 3, Riverpod, GoRouter, and Hive.

---

## 🚀 Quick Start

### Prerequisites

1. **Flutter SDK** (latest stable) — [Install Flutter](https://docs.flutter.dev/get-started/install/windows/mobile)
2. **Android SDK** (API 23+)
3. **Android Studio** or **VS Code** with Flutter extension

### Setup

```bash
# 1. Clone / navigate to project
cd "e:/Phone Addiction Controller"

# 2. Install dependencies
flutter pub get

# 3. Run on connected Android device or emulator
flutter run

# 4. Build debug APK
flutter build apk --debug

# 5. Build release APK (personal use)
flutter build apk --release
```

---

## 📁 Project Structure

```
lib/
├── main.dart                          # App entry point
├── core/
│   ├── constants/
│   │   ├── app_constants.dart         # Global constants
│   │   └── route_names.dart           # Route paths
│   ├── providers/
│   │   └── service_providers.dart     # Riverpod service providers
│   ├── router/
│   │   └── app_router.dart            # GoRouter configuration
│   └── theme/
│       └── app_theme.dart             # Material 3 theme (light + dark)
│
├── data/
│   └── local/
│       └── hive_boxes.dart            # Hive initialization & box registration
│
├── domain/
│   └── models/
│       ├── focus_session.dart         # FocusSession Hive model
│       ├── routine.dart               # Routine Hive model
│       ├── allowed_app.dart           # AllowedApp Hive model
│       └── admin_settings.dart        # AdminSettings Hive model
│
├── features/
│   ├── home/presentation/pages/
│   │   └── home_page.dart             # Dashboard with status & quick actions
│   ├── allowed_apps/presentation/pages/
│   │   └── allowed_apps_page.dart     # App whitelist management
│   ├── schedule/presentation/pages/
│   │   └── schedule_page.dart         # Routine scheduling
│   ├── settings/presentation/pages/
│   │   └── settings_page.dart         # App settings
│   ├── admin/presentation/pages/
│   │   └── admin_password_page.dart   # Admin password setup
│   └── focus_session/presentation/pages/
│       └── focus_session_page.dart    # Timer + blocking controls
│
├── services/
│   ├── interfaces/                    # Abstract service contracts
│   │   ├── accessibility_service_manager.dart
│   │   ├── app_blocking_service.dart
│   │   ├── installed_apps_service.dart
│   │   ├── schedule_service.dart
│   │   ├── password_service.dart
│   │   └── storage_service.dart
│   └── impl/                          # Stub implementations with TODOs
│       ├── accessibility_service_manager_impl.dart
│       ├── app_blocking_service_impl.dart
│       ├── installed_apps_service_impl.dart
│       ├── schedule_service_impl.dart
│       ├── password_service_impl.dart
│       └── storage_service_impl.dart
│
└── widgets/                           # Shared UI components
    ├── scaffold_with_nav_bar.dart     # Bottom nav scaffold
    ├── status_card.dart               # Focus mode status card
    ├── section_header.dart            # Reusable section header
    └── settings_tile.dart             # Reusable settings row

android/
├── app/
│   ├── build.gradle                   # App build config (minSdk 23)
│   └── src/main/
│       ├── AndroidManifest.xml        # All permissions declared
│       └── res/xml/
│           └── accessibility_service_config.xml
├── build.gradle                       # Root build config
├── settings.gradle                    # Plugin management
└── gradle.properties                  # JVM & Android settings
```

---

## 🏗️ Architecture

```
Presentation  →  Riverpod Providers  →  Service Interfaces
                                              ↓
                                    Concrete Implementations
                                              ↓
                                    Hive / Platform Channels
```

- **Clean Architecture**: domain models, service interfaces, concrete impls
- **Riverpod**: state management and dependency injection
- **GoRouter**: declarative navigation with StatefulShellRoute
- **Hive**: local persistence for sessions, apps, routines, settings

---

## 📱 Pages

| Page | Route | Description |
|------|-------|-------------|
| Home | `/` | Dashboard, status, permissions |
| Allowed Apps | `/allowed-apps` | App whitelist management |
| Schedule | `/schedule` | Recurring routine setup |
| Settings | `/settings` | All app settings |
| Focus Session | `/focus-session` | Timer + blocking controls |
| Admin Password | `/admin-password` | Security password setup |

---

## 🔧 Next Steps (Business Logic)

The following services have stub implementations with `TODO` comments:

1. **AccessibilityServiceManagerImpl** — Platform channel → Kotlin `FocusAccessibilityService`
2. **AppBlockingServiceImpl** — Connect to accessibility service for blocking
3. **InstalledAppsServiceImpl** — Platform channel → Android PackageManager
4. **ScheduleServiceImpl** — Android AlarmManager / WorkManager
5. **PasswordServiceImpl** — Complete Hive integration (hashing is done)

### Required Android Kotlin Files (to implement later)

- `android/app/src/main/kotlin/.../services/FocusAccessibilityService.kt`
- `android/app/src/main/kotlin/.../services/FocusBlockingService.kt`
- `android/app/src/main/kotlin/.../receivers/BootReceiver.kt`

---

## 🔐 Required Android Permissions (Manual Grant Needed)

Since this is a personal-use app, you must manually enable:

1. **Accessibility Service**: Settings → Accessibility → Focus Guard
2. **Draw Over Other Apps**: Settings → Apps → Focus Guard → Display over other apps
3. **Usage Access**: Settings → Digital Wellbeing → Usage access → Focus Guard

---

## 🎨 Design

- **Dark Mode** by default (forced)
- **Primary Color**: `#6C63FF` (violet-purple)
- **Font**: Inter (via `google_fonts`)
- **Cards**: Rounded (20px), frosted glass feel
- **Animations**: `flutter_animate` for page entries and micro-interactions

---

## 📦 Key Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `flutter_riverpod` | ^2.5.1 | State management |
| `go_router` | ^14.2.7 | Navigation |
| `hive_flutter` | ^1.1.0 | Local storage |
| `google_fonts` | ^6.2.1 | Inter font |
| `flutter_animate` | ^4.5.0 | Animations |
| `crypto` | ^3.0.3 | SHA-256 hashing |
| `equatable` | ^2.0.5 | Value equality |
| `permission_handler` | ^11.3.1 | Runtime permissions |
