# Optional Device Owner test-device guide

**Use a spare, eligible test device only. Do not run these steps on a personal phone.** Device Owner is a managed-device role, not the same as activating Device Admin. Provisioning generally requires the device to be new/factory-reset and before accounts or normal device setup are completed. A factory reset erases device data.

Focus Guard's owner-mode switch calls `DevicePolicyManager.setUninstallBlocked` only after Android reports this app as a Device Owner or Profile Owner. The app does not silently provision, reset, lock, or wipe a device. Its Device Admin declaration requests no policies.

## Test provisioning with ADB

1. Use an eligible spare Android device and follow Android's supported setup/provisioning requirements for its OS and OEM. Keep it in the required fresh, unprovisioned state; do not remove accounts or reset a device containing personal data for this test.
2. Install a release APK signed with the test app's intended, backed-up signing key. Avoid the `.debug` variant because it has a different package ID.
3. Before adding accounts or completing managed provisioning, connect authorized ADB and confirm the target serial:

```powershell
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
& $adb devices -l
$device = "IP:port"
```

4. Install and set the owner only on that test device:

```powershell
& $adb -s $device install .\build\app\outputs\flutter-apk\app-release.apk
& $adb -s $device shell dpm set-device-owner com.personal.phone_addiction_controller/.receivers.FocusDeviceAdminReceiver
```

Android may reject the command if the device is already provisioned, has accounts/users that are incompatible with owner setup, or the build/OEM disallows that provisioning path. Stop if it is rejected; do not attempt to bypass device eligibility or run a reset without the test-device owner's informed approval.

5. Confirm the role from Android, then launch Focus Guard and refresh Admin Settings:

```powershell
& $adb -s $device shell dumpsys device_policy
& $adb -s $device shell monkey -p com.personal.phone_addiction_controller 1
```

The UI must report Device Owner only when `DevicePolicyManager.isDeviceOwnerApp` says it is true. Enable **Android-managed uninstall block** explicitly and verify the state refreshes. This policy applies to the owner-managed device; a Profile Owner is limited to its managed profile.

## Owner-mode recovery

On a working installation, use Focus Guard's **Deactivate Device Admin** or **Uninstall Focus Guard** action and complete the configured partner-password check. The app clears its own uninstall block and relinquishes Device Owner before requesting Android's uninstall confirmation. Confirm Android's resulting status in `dumpsys device_policy`.

If the app is unavailable or cannot relinquish ownership, use the legitimate enterprise/DPC administrator recovery process for that test device. If no such recovery is configured, use the device manufacturer's supported factory-reset recovery only after the device owner accepts the data loss. Do not try shell commands that impersonate system policy privileges or silently remove management.

## Official references

- [Android dedicated-device provisioning](https://developer.android.com/work/dpc/dedicated-devices)
- [Android Device Policy Controller provisioning](https://developer.android.com/work/dpc/provisioning)
- [DevicePolicyManager API](https://developer.android.com/reference/android/app/admin/DevicePolicyManager)
