# Detox – Amazon Appstore Reviewer Notes

Detox helps users limit their own phone use by blocking apps they choose, on a timer or schedule. The app is completely offline (`INTERNET` permission is not requested), contains **zero ad network or analytics SDKs**, and all settings/schedules stay strictly on the device.

## Resubmission note (Content Policy Validation – Third-party / framework libraries)
Our previous build (`1.0.0+1`) included unused default Flutter plugins in `pubspec.yaml` (`permission_handler`, `file_picker`, `share_plus`, `path_provider` / `jni`) that Flutter's `GeneratedPluginRegistrant` kept in the release DEX and native libraries (`libdartjni.so`). Although unused by the app, those framework libraries contained bytecode references to location, telephony, Bluetooth advertising, overlay, and package-install APIs. All unused plugins and native JNI libraries have been completely removed from `pubspec.yaml` and the packaged APK (`1.0.0+2`).

## Permissions and why they are needed
| Permission / feature | Purpose |
|---|---|
| Accessibility Service | Detects which app is in the foreground so a user-selected blocked app can be covered by the Focus Mode block screen. If the user separately enables the optional screen guard in Settings, it checks visible Settings/installer text for Detox removal actions. Accessibility data is processed in-memory on the device and is never stored or transmitted. |
| QUERY_ALL_PACKAGES | Lists installed user-launchable apps so the user can pick which apps to block during Focus Mode. |
| Device Admin (optional) | Optional deterrent enabled by the user so Android asks to deactivate Device Admin before uninstalling. Requests zero device-admin policies (`<uses-policies />` is empty). |
| FOREGROUND_SERVICE (special use) | Keeps the active Focus Mode timer and app-blocking session running reliably while a session is active. |
| RECEIVE_BOOT_COMPLETED | Restores scheduled focus routines after a device reboot. |
| SCHEDULE_EXACT_ALARM / USE_EXACT_ALARM | Starts and ends user-scheduled focus routines at their configured times. |
| POST_NOTIFICATIONS | Shows the active focus session countdown and routine alerts. |
| REQUEST_IGNORE_BATTERY_OPTIMIZATIONS | Optional setting to prevent the OS from stopping an active focus timer in the background. |

## Test steps
1. Install and open the app. Complete first-run setup and **create a test PIN** (e.g. any 4 digits you choose).
2. Grant notification permission when asked.
3. Tap the Accessibility prompt -> Settings -> Installed apps -> Detox -> turn **On** and accept the dialog.
4. Go to app selection and choose one or two apps (e.g. a browser or a game).
5. Start a short focus session (1–2 minutes).
6. Open a selected app: the block screen should appear. Unselected apps work normally.
7. Optionally test the emergency access option and a scheduled routine a couple of minutes ahead.
8. Wait for the session to end; blocking stops.

No account or login is required. No credentials are needed for review.
