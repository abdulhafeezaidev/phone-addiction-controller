# Bloomly — Phone Addiction Controller & Mindful Focus Engine

A high-assurance Android & Flutter application designed to conquer smartphone addiction through hardware-level device administration, tamper-proof accessibility enforcement, and mindful behavioral psychology.

---

## Architecture Overview

```text
+-----------------------------------------------------------------------------------+
|                        Flutter Presentation Layer (Dart)                          |
|                                                                                   |
|  - Bloomly UX & Lumi Mascot (7 emotional mood states, interactive speech bubbles) |
|  - Ambient Soundscape Engine (Solfeggio 528Hz bell, dewdrop plucks, voice audio)  |
|  - Riverpod State Architecture & GoRouter Declarative Routing                     |
|  - Local Storage (Hive encrypted boxes for routines, sessions, and credentials)   |
+-----------------------------------------+-----------------------------------------+
                                          |
                                          | MethodChannel / EventChannel Bridge
                                          v
+-----------------------------------------------------------------------------------+
|                        Android Native Security Core (Kotlin)                      |
|                                                                                   |
|  [ TamperGuard ]                    [ FocusSessionController ]                    |
|  - Anti-uninstall protection        - DevicePolicyManager (Device Admin API)      |
|  - Settings bypass prevention       - Active session lock state machine           |
|                                                                                   |
|  [ AccessibilityOverlayManager ]    [ FocusForegroundService ]                    |
|  - System window blocking overlay   - Persistent sticky notification              |
|  - In-place interception of black-  - AlarmManager exact routine triggers         |
|    listed package foreground events                                               |
+-----------------------------------------------------------------------------------+
```

---

## Core Capabilities

1. **Tamper-Proof Native Enforcement**:
   - **Device Admin Integration**: Employs Android `DevicePolicyManager` to restrict unauthorized uninstallation and settings clearing while focus mode is active.
   - **Accessibility Service Interception**: Real-time foreground package detection instantly captures unauthorized app launches and displays the blocking overlay in less than 50ms.
   - **Emergency Override Architecture**: Features a mandatory reflection cooldown timer and cryptographic verification challenge before allowing policy modifications.

2. **Lumi Mindful Mascot & Audio Experience**:
   - **7 Emotional States**: Adaptive character states based on session streaks and focus discipline.
   - **Acoustic Solfeggio Soundscapes**: Integrated 528Hz frequency meditation tones and ambient water drop chimes to soothe notification anxiety during deep work sessions.

3. **Offline-First & Privacy Preserving**:
   - 100% on-device operation. Zero personal data, application usage patterns, or screen contents leave the device.
   - Stored in local Hive boxes and SharedPreferences with zero cloud dependencies.

---

## Technology Stack

- **Framework**: Flutter 3.x (Dart 3)
- **State Management**: Riverpod (StateNotifier / AsyncNotifier)
- **Local Persistence**: Hive, Flutter Secure Storage
- **Native Android Layer**: Kotlin, Android Accessibility API, DevicePolicyManager, Foreground Services, BroadcastReceivers
- **Audio Engine**: Just Audio / Soundpool for low-latency acoustic feedback
- **Testing**: Flutter Test framework with 100% passing unit, service, and widget test suites

---

## Project Structure

```text
phone-addiction-controller/
├── android/
│   ├── app/src/main/kotlin/.../
│   │   ├── FocusSessionController.kt        # Native focus state machine
│   │   ├── TamperGuard.kt                   # Anti-uninstall & tamper protection
│   │   ├── FlutterBridge.kt                 # MethodChannel communication
│   │   ├── receivers/                       # BootReceiver, DeviceAdminReceiver
│   │   └── services/
│   │       ├── AccessibilityMonitorService.kt
│   │       ├── AccessibilityOverlayManager.kt
│   │       └── FocusForegroundService.kt
│   └── app/src/main/res/xml/                # Device admin & accessibility configs
├── lib/
│   ├── core/                                # Theme tokens, constants, router
│   ├── data/                                # Hive local data repositories
│   ├── domain/models/                       # Session, Routine, Admin settings
│   ├── features/
│   │   ├── home/                            # Bloomly home screen & Lumi Mascot
│   │   ├── focus/                           # Focus session launcher & overlay
│   │   ├── schedule/                        # Automated daily focus routines
│   │   └── emergency/                       # Cooldown reflection & emergency override
│   └── services/                            # Soundscapes, native bridge, password
├── docs/                                    # Technical architecture & screenshots
│   └── screenshots/                         # Application UI capture gallery
└── test/                                    # Unit, service, and mascot widget tests
```

---

## Setup & Development

### Prerequisites
- Flutter SDK `3.19+` or `3.24+`
- Android SDK (API Level 34+ recommended, minimum API 23)
- Physical Android device (required to test Device Administrator and Accessibility overlay permissions)

### Installation
```bash
flutter pub get
```

### Running Automated Tests
```bash
flutter test
```

### Building Debug APK
```bash
flutter build apk --debug
```

### Installing on Device with Device Admin
```bash
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```
*Note: Grant Accessibility Service and Device Administrator permissions when prompted on first launch.*
