# Android uninstall protection

Focus Guard offers three distinct protection levels. None is a promise that an ordinary personal Android phone cannot be reset or that its owner cannot remove the app.

| Layer | What it does | Android authority |
| --- | --- | --- |
| Device Admin | Android requires the administrator to be deactivated before uninstalling Focus Guard. The app asks for the configured admin password before it voluntarily deactivates this role. | Android enforces the extra deactivation step; it does not require Focus Guard's password in system Settings. |
| Screen guard | The existing, user-enabled Accessibility service looks for Focus Guard's own removal actions in Settings and package-installer screens, then asks for in-app authentication. | Best-effort only. The owner can disable Accessibility, force-stop the app, or use another supported system path. It must not be treated as an OS security boundary. |
| Device Owner / Profile Owner | `DevicePolicyManager.setUninstallBlocked` can block removal when Android has legitimately provisioned Focus Guard as an owner. | Android-enforced for the device (Device Owner) or managed profile (Profile Owner). This is a separate managed-device setup, not available after an ordinary APK install. |

The Device Admin XML requests no policies. Focus Guard does not request Usage Access or add an Accessibility service for uninstall protection: its existing, user-visible app-blocking Accessibility service is reused. Status is queried from Android when the Settings page opens/resumes; a saved screen-guard preference is reported separately from whether Accessibility is currently enabled.

## Build and install on Windows

Run these commands from the repository root. They do not grant Device Admin, Accessibility, or owner privileges.

```powershell
flutter pub get
flutter test
flutter analyze

$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
& $adb devices -l
```

Select the exact authorized serial printed by `adb devices -l` (for wireless debugging it is usually `IP:port`) and build/install a debug APK:

```powershell
$device = "IP:port"
flutter build apk --debug
& $adb -s $device install -r .\build\app\outputs\flutter-apk\app-debug.apk
& $adb -s $device shell monkey -p com.personal.phone_addiction_controller.debug 1
```

The debug variant uses the `.debug` application ID and can be installed alongside the release variant. To update the release variant instead, use `app-release.apk` and the base application ID below. Android only permits an in-place update when the installed app and new APK have the same signing certificate; do not uninstall the existing app to work around a signature mismatch, because that removes its data and active admin state.

## Release APK signing

Release builds require a production keystore and `android\key.properties`; they fail rather than silently using the Android debug key. No keystore or signing secrets are included in this repository.

Create and securely back up an upload/release keystore using your key-management process. Losing the key can prevent future updates, so preserve a protected backup. Copy `android\key.properties.example` to `android\key.properties`, fill in the keystore path and credentials, and keep both files out of version control. Never paste signing secrets into source code, chat, or build logs. The example file uses a placeholder path and empty passwords; a release build will reject it until configured. Then:

```powershell
flutter build apk --release
$sdkDir = ((Select-String '^sdk.dir=' .\android\local.properties).Line -split '=', 2)[1].Replace('\\', '\')
$buildToolsDir = Get-ChildItem (Join-Path $sdkDir 'build-tools') -Directory |
    Sort-Object Name | Select-Object -Last 1
$apksigner = Join-Path $buildToolsDir.FullName 'apksigner.bat'
& $apksigner verify --print-certs .\build\app\outputs\flutter-apk\app-release.apk
$adb = Join-Path $sdkDir 'platform-tools\adb.exe'
$device = "IP:port"
& $adb -s $device install -r .\build\app\outputs\flutter-apk\app-release.apk
& $adb -s $device shell monkey -p com.personal.phone_addiction_controller 1
```

Before updating a device that already has Focus Guard, confirm the release keystore matches that installation's signing certificate. Do not use `adb uninstall` as a signing workaround. Increment the build number in `pubspec.yaml` for each new store upload.

## Amazon Appstore review preparation

In the Appstore listing and reviewer notes, explain that installed-app visibility supports app selection/blocking, the user-enabled Accessibility service enforces Focus Mode, and the special-use foreground service keeps an active session reliable. Disclose any other permissions requested by the final merged APK and describe their user-facing purpose; do not claim Android prevents force-stop, settings changes, or uninstall.

Provide clear reviewer steps: finish first-run setup and create an admin PIN, enable the Accessibility service from Android Settings, select apps, start a short focus session, and verify that selected apps are blocked and allowed apps remain available. Explain that Accessibility, notifications, and some device-management features require user action and may vary on Fire OS. Use a test device/account and a temporary test PIN if review needs one; do not include production credentials in the listing or notes.

## Setup and device checklist

1. Launch Focus Guard and finish normal onboarding. The Accessibility service is needed for the existing app-blocking feature; Device Admin and the screen guard are optional.
2. In **Admin Settings**, enable Device Admin only if you want Android's extra deactivation step. Accept or decline in Android's official confirmation screen; return to the app and refresh/check the actual status.
3. The screen guard is separate. Enable it only after enabling Focus Guard's existing Accessibility service through Android Settings. Android may show warnings for Accessibility services. The guard preference does not silently turn that service on.
4. If the device is not a Device Owner/Profile Owner, the Android-managed uninstall-block switch is unavailable. Standard APK installation cannot grant those roles.
5. Test the in-app Device Admin deactivation and screen-guard pause with a wrong password, cancellation, and the correct configured password. Wrong password/cancel must leave the in-app protection setting unchanged.
6. With the optional screen guard enabled, visit unrelated apps' information screens and confirm they are not interrupted. Visit Focus Guard's own app-info/uninstall flow and the Device Admin deactivation flow to assess the best-effort prompt on the actual OEM build.
7. Turn off the Accessibility service from Android Settings and verify the app reports the guard as inactive. Re-enable it manually and verify Android rebinds the existing service. Reboot and repeat; Android can delay, restrict, or disable background services, so verify the displayed status rather than assuming recovery.
8. Verify the Device Admin state in Android's Device Admin apps screen. Deactivate it through Focus Guard's authenticated action and separately confirm that Android's system UI remains the final authority for uninstall.
9. Do not enable Device Owner on a personal phone as part of this checklist. Use the separate [test-device provisioning guide](device-owner-test-guide.md).

Useful read-only checks:

```powershell
& $adb -s $device shell dumpsys device_policy
& $adb -s $device shell settings get secure enabled_accessibility_services
```

## Authentication and recovery

The in-app voluntary deactivation flows use the existing accountability-partner password dialog, failed-attempt counter, and lockout. The app persists a salted password hash, not the plaintext password. This repository does **not** currently encrypt the Hive box with a key protected by Android Keystore, and it does not implement biometric authentication; do not describe this local hash as encrypted storage or as a hardware-backed credential.

For a legitimate owner on an ordinary device, Android Settings remains the recovery authority: turn off Focus Guard's Accessibility service if needed, deactivate Focus Guard under **Device admin apps**, then uninstall it using Android's app-management screen. Device Admin alone does not make this recovery require the in-app password. If the app's authenticated removal screen is used instead, it opens Android's standard uninstall confirmation after deactivation; if that confirmation is cancelled, the guard's temporary bypass expires after two minutes.

If Android cannot release a Device Owner because Focus Guard is unavailable, use the device's supported enterprise/DPC recovery or factory-reset procedure for that test device. A factory reset erases local data; do not perform it as routine troubleshooting.

## Platform limitations

- Device Admin is a deterrent and system-managed deactivation step, not Device Owner. A user can deactivate it from Android Settings without Focus Guard's PIN.
- Accessibility events and visible text vary by Android release and OEM (including Samsung One UI). The screen guard can miss flows or be bypassed by disabling its Accessibility service, force-stopping the app, using Safe Mode, ADB, another user/profile, or resetting the device. It does not cover every installer or Settings screen.
- No app process can guarantee it will run after force-stop, battery management, app-data clearing, uninstall, or reset. Android's Accessibility service must stay enabled by the user; Focus Guard does not turn it back on.
- Device Owner and Profile Owner are distinct managed roles. Owner-only `setUninstallBlocked` is called only when Android reports an owner role. A Profile Owner policy is limited to its managed profile.
- The existing password hash uses a 1,000-round custom HMAC-SHA256 derivation and is stored in an unencrypted Hive box. It is not plaintext, but it is not a strong, hardware-backed or encrypted credential store; offline guessing is a known limitation, especially for short passwords.

## Reference review and licenses

The implementation reuses Focus Guard's existing service and Android APIs; it does not copy source code from these projects.

- [OpenLock](https://github.com/MalicKAbdullah/openlock) — reviewed receiver, monitor service, manifest, and Flutter bridge; repository declares MIT.
- [AndroidPhoneManager](https://github.com/TTeuber/AndroidPhoneManager) — reviewed receiver, device-admin XML, and setup material; repository declares MIT.
- [AppBlocker](https://github.com/TheHelixCore/AppBlocker) — reviewed receiver, Accessibility service, and manifest. No license was found in the reviewed repository, so none of its code is reused.
- [Android `DevicePolicyManager`](https://developer.android.com/reference/android/app/admin/DevicePolicyManager) — official API reference.

No third-party source was adapted, so no additional third-party source license notice is required for these changes.
