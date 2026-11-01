package com.personal.phone_addiction_controller

import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import java.util.Locale

/**
 * FocusPolicyEngine - single source of truth for enforcement decisions.
 *
 * Every foreground package transition goes through [evaluate]. Pipeline:
 *  1. Is a session running (and not past its end time)?  -> else ALLOW
 *  2. Is the emergency override active?                  -> ALLOW
 *  3. Is this our own app?                               -> ALLOW
 *  4. Is this critical system infrastructure?            -> ALLOW (telecom, IME, SystemUI...)
 *  5. Is this a launcher / home screen?                  -> ALLOW
 *  6. Is this package on the user's block list?          -> BLOCK
 *  7. Everything else                                    -> ALLOW
 */
class FocusPolicyEngine(private val context: Context) {

    enum class Decision { ALLOW, BLOCK }

    private val pm: PackageManager = context.packageManager

    // Cached set of launcher packages (resolved once, reset on demand)
    private val launcherPackages: Set<String> by lazy { resolveLauncherPackages() }

    // ── Public API ───────────────────────────────────────────────────────────

    /**
     * The only place in the codebase that decides ALLOW or BLOCK.
     *
     * @param packageName The foreground package to evaluate.
     * @param className The class name of the window (used to detect Recents UI)
     * @return [Decision.ALLOW] or [Decision.BLOCK].
     */
    fun evaluate(packageName: String?, className: String? = null): Decision {
        if (packageName.isNullOrBlank()) return Decision.ALLOW

        Log.d(TAG, "Evaluating: pkg=$packageName, class=$className, isActive=${FocusModeManager.isActive}")

        // 1. A session must be running; quick sessions end themselves at their end time
        if (FocusModeManager.hasQuickSessionExpired()) {
            Log.d(TAG, "Quick session expired")
            FocusSessionController.onQuickSessionExpired(context)
            return evaluate(packageName, className)
        }
        if (!FocusModeManager.isActive) {
            Log.d(TAG, "ALLOW: Focus Mode is inactive")
            return Decision.ALLOW
        }

        // 2. Emergency override
        if (FocusModeManager.isEmergencyOverrideActive()) {
            Log.d(TAG, "ALLOW: Emergency override is active")
            return Decision.ALLOW
        }

        // 3. Focus Home (our own app)
        if (packageName == context.packageName) {
            Log.d(TAG, "ALLOW: Focus Home (our own app)")
            return Decision.ALLOW
        }

        // 4. Critical system infrastructure that MUST always be allowed
        //    This includes telecom (incoming AND outgoing calls), IME, SystemUI, etc.
        if (isCriticalSystemInfrastructure(packageName)) {
            Log.d(TAG, "ALLOW: Critical system infrastructure ($packageName)")
            return Decision.ALLOW
        }

        // 5. In Personal Mode: Launchers / Home screens are ALLOWED
        if (isLauncherPackage(packageName)) {
            Log.d(TAG, "ALLOW: Launcher/Home app ($packageName)")
            return Decision.ALLOW
        }

        // 6. Explicitly blocked packages in Personal Mode
        if (FocusModeManager.blockedPackages.contains(packageName)) {
            Log.d(TAG, "BLOCK: Explicitly blocked package ($packageName)")
            DiagnosticsLogger.appBlocked(packageName)
            return Decision.BLOCK
        }

        // 7. Everything else remains ALLOWED in Personal Mode
        Log.d(TAG, "ALLOW: Package not blocked ($packageName)")
        return Decision.ALLOW
    }

    // ── Private / Internal Helpers ───────────────────────────────────────────

    /**
     * Critical system infrastructure that must ALWAYS be allowed during Focus Mode.
     * This includes:
     * - Phone/Dialer/InCallUI (incoming AND outgoing calls)
     * - Telecom framework
     * - Contacts (required by dialer for caller ID)
     * - Messages/SMS
     * - Input methods (keyboards)
     * - SystemUI
     * - Google Play Services (framework)
     * - Android framework
     * - Camera
     * - Calculator
     * - Clock/Alarm
     * - File managers / Downloads
     * - Bluetooth/Wi-Fi/NFC system UIs
     * - Emergency services
     * - Audio system
     */
    fun isCriticalSystemInfrastructure(packageName: String): Boolean {
        // Dynamic check: default dialer package & ACTION_DIAL / ACTION_CALL intent handlers
        if (getDynamicCommunicationPackages().contains(packageName)) return true

        // Check against our comprehensive whitelist
        if (CRITICAL_SYSTEM_PACKAGES.contains(packageName)) return true

        // Check prefix-based patterns for vendor-specific packages
        val lower = packageName.lowercase(Locale.ROOT)
        for (prefix in CRITICAL_SYSTEM_PREFIXES) {
            if (lower.startsWith(prefix)) return true
        }

        return false
    }

    fun getDynamicCommunicationPackages(): Set<String> {
        val result = mutableSetOf<String>()
        try {
            val telecomManager = context.getSystemService(Context.TELECOM_SERVICE) as? android.telecom.TelecomManager
            telecomManager?.defaultDialerPackage?.let { if (it.isNotBlank()) result.add(it) }

            val dialIntent = Intent(Intent.ACTION_DIAL)
            val dialResolves = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                pm.queryIntentActivities(dialIntent, PackageManager.ResolveInfoFlags.of(0L))
            } else {
                @Suppress("DEPRECATION")
                pm.queryIntentActivities(dialIntent, 0)
            }
            for (info in dialResolves) {
                info.activityInfo?.packageName?.let { if (it.isNotBlank()) result.add(it) }
            }

            val smsPackage = android.provider.Telephony.Sms.getDefaultSmsPackage(context)
            if (!smsPackage.isNullOrBlank()) {
                result.add(smsPackage)
            }
        } catch (e: Exception) {
            Log.w(TAG, "Error resolving dynamic communication packages", e)
        }
        return result
    }

    fun isLauncherPackage(packageName: String): Boolean {
        if (launcherPackages.contains(packageName)) return true
        val lower = packageName.lowercase(Locale.ROOT)
        return KNOWN_LAUNCHERS.contains(lower) ||
            lower.endsWith(".launcher") ||
            lower.contains("launcher") ||
            lower.endsWith(".home")
    }

    private fun resolveLauncherPackages(): Set<String> {
        val intent = Intent(Intent.ACTION_MAIN).apply { addCategory(Intent.CATEGORY_HOME) }
        val infos = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            pm.queryIntentActivities(intent, PackageManager.ResolveInfoFlags.of(0L))
        } else {
            @Suppress("DEPRECATION")
            pm.queryIntentActivities(intent, 0)
        }
        return infos.mapNotNull { it.activityInfo?.packageName }.toSet()
    }

    companion object {
        private const val TAG = "FocusPolicyEngine"

        val KNOWN_LAUNCHERS = setOf(
            "com.sec.android.app.launcher",
            "com.samsung.android.app.homup",
            "com.google.android.apps.nexuslauncher",
            "com.miui.home",
            "com.oppo.launcher",
            "com.coloros.launcher",
            "com.huawei.android.launcher",
            "com.vivo.launcher",
            "com.oneplus.launcher",
            "com.android.launcher",
            "com.android.launcher3",
            "com.microsoft.launcher",
            "com.nova.launcher",
            "com.teslacoilsw.launcher",
            "com.action.launcher",
            "com.ss.android.auto.luancher"
        )

        /**
         * Comprehensive whitelist of system packages that must NEVER be blocked.
         * These are the packages that enable core device functionality.
         */
        val CRITICAL_SYSTEM_PACKAGES = setOf(
            // ── Android Framework ───────────────────────────────────────────
            "android",
            "com.android.systemui",
            "com.android.system",

            // ── Phone / Dialer / InCallUI (INCOMING + OUTGOING calls) ───────
            "com.android.phone",
            "com.android.server.telecom",
            "com.android.telecom",
            "com.android.dialer",
            "com.android.incallui",
            "com.android.phone.slice",
            // Samsung
            "com.samsung.android.incallui",
            "com.samsung.android.dialer",
            "com.samsung.android.app.telephonyui",
            "com.samsung.android.telecom",
            "com.samsung.android.phone",
            // Google
            "com.google.android.dialer",

            // ── Contacts ────────────────────────────────────────────────────
            "com.android.contacts",
            "com.samsung.android.contacts",
            "com.google.android.contacts",
            "com.android.providers.contacts",

            // ── Messages / SMS ──────────────────────────────────────────────
            "com.android.mms",
            "com.samsung.android.messaging",
            "com.google.android.apps.messaging",
            "com.android.providers.telephony",

            // ── Camera ──────────────────────────────────────────────────────
            "com.android.camera",
            "com.android.camera2",
            "com.sec.android.app.camera",
            "com.samsung.android.app.camera",
            "com.google.android.GoogleCamera",
            "com.samsung.android.cameralite",

            // ── Calculator ──────────────────────────────────────────────────
            "com.android.calculator2",
            "com.sec.android.app.popupcalculator",
            "com.samsung.android.calculator",
            "com.google.android.calculator",

            // ── Clock / Alarms ──────────────────────────────────────────────
            "com.android.deskclock",
            "com.sec.android.app.clockpackage",
            "com.samsung.android.app.clockpackage",
            "com.google.android.deskclock",

            // ── Files / Downloads ───────────────────────────────────────────
            "com.android.documentsui",
            "com.android.providers.downloads",
            "com.android.providers.downloads.ui",
            "com.android.providers.media",
            "com.android.externalstorage",
            "com.sec.android.app.myfiles",
            "com.google.android.apps.nbu.files",
            "com.samsung.android.app.myfiles",

            // ── Package Installer (allow APK installation dialogs) ──────────
            "com.android.packageinstaller",
            "com.google.android.packageinstaller",
            "com.samsung.android.packageinstaller",

            // ── Google Play Services / Framework ────────────────────────────
            "com.google.android.gms",
            "com.google.android.gsf",
            "com.google.android.providers.media.module",
            "com.google.android.ext.services",
            "com.google.android.ext.shared",

            // ── Input Methods (Keyboards) ───────────────────────────────────
            "com.samsung.android.honeyboard",
            "com.google.android.inputmethod.latin",
            "com.android.inputmethod.latin",
            "com.swiftkey.swiftkey",

            // ── Bluetooth ───────────────────────────────────────────────────
            "com.android.bluetooth",
            "com.samsung.android.app.sharelive",
            "com.samsung.android.bluetooth",

            // ── Wi-Fi ───────────────────────────────────────────────────────
            "com.android.wifi",
            "com.android.wifi.dialog",
            "com.samsung.android.wifi",
            "com.android.providers.settings",

            // ── NFC ─────────────────────────────────────────────────────────
            "com.android.nfc",
            "com.samsung.android.service.tagservice",

            // ── Audio / Sound ───────────────────────────────────────────────
            "com.android.server.audio",
            "com.samsung.android.app.soundpicker",

            // ── Emergency / SOS ─────────────────────────────────────────────
            "com.android.emergency",
            "com.sec.android.app.safetyassurance",
            "com.samsung.android.emergency",

            // ── Samsung System UI ───────────────────────────────────────────
            "com.samsung.android.systemui",
            "com.samsung.android.app.routines",
            "com.samsung.android.lool", // Note: this is intentionally NOT blocked in isSettingsPackage because we allow it here only as a system infra (not launchable)
            "com.samsung.android.biometrics.app.setting",
            "com.samsung.android.app.smartcapture",
            "com.samsung.android.app.clipboardedge",
            "com.samsung.android.app.cocktailbarservice",
            "com.samsung.android.mdx",
            "com.samsung.android.app.taskedge",
        )

        /**
         * Prefix-based patterns for vendor system packages.
         * Any package starting with these prefixes is considered critical infrastructure.
         */
        private val CRITICAL_SYSTEM_PREFIXES = listOf(
            "com.android.providers.",     // All content providers
            "com.android.server.",        // All system servers
            "com.android.internal.",      // Internal framework
            "com.android.keychain",       // Certificate management
            "com.android.location",       // Location services
            "com.android.networkstack",   // Network stack
            "com.android.permissioncontroller", // Permission UI
            "com.android.se.",            // Secure element
            "com.android.certinstaller",  // Certificate installer
            "com.android.packageinstaller", // Package installer
            "com.google.android.packageinstaller",
            "com.samsung.android.packageinstaller",
        )
    }
}
