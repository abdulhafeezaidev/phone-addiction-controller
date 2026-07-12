package com.personal.phone_addiction_controller

import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import java.util.Locale

/**
 * FocusPolicyEngine — Single Source of Truth for All Enforcement Decisions.
 *
 * Every foreground package transition during Focus Mode MUST go through here.
 * Nothing else in the codebase decides whether a package is allowed or blocked.
 *
 *  Decision pipeline:
 *  1. Is Focus Mode even active?               → ALLOW
 *  2. Is emergency override active?             → ALLOW
 *  3. Is this our own Focus Home package?       → ALLOW
 *  4. Is this a critical system infrastructure? → ALLOW  (telecom, IME, SystemUI)
 *  5. Is this a launcher (home screen)?         → BLOCK  (prevents Home bypass)
 *  6. Is this an assistant / voice app?         → BLOCK  (prevents voice bypass)
 *  7. Is this Settings or Package Installer?    → BLOCK  (prevents uninstall bypass)
 *  8. Is this the Recent Apps UI?               → BLOCK  (prevents task switching)
 *  9. Is this in the alwaysAllowedApps list?    → ALLOW
 * 10. Is this in the user's allowedApps list?   → ALLOW
 * 11. Is this a non-launchable system package?  → ALLOW  (SystemUI, framework, etc.)
 * 12. Everything else                           → BLOCK
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

        // 1. Focus Mode must be active
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

        // 5. Launchers / Home screens are ALWAYS blocked during focus
        if (isLauncherPackage(packageName)) {
            Log.d(TAG, "BLOCK: Launcher/Home app ($packageName)")
            return Decision.BLOCK
        }

        // 6. Voice assistants are ALWAYS blocked during focus
        if (isAssistantPackage(packageName)) {
            Log.d(TAG, "BLOCK: Voice assistant ($packageName)")
            return Decision.BLOCK
        }

        // 7. Settings app is ALWAYS blocked to prevent uninstall/accessibility bypasses
        if (isSettingsPackage(packageName)) {
            Log.d(TAG, "BLOCK: Settings app ($packageName)")
            return Decision.BLOCK
        }

        // 7b. Package installer is ALWAYS blocked during focus to prevent uninstallation
        if (isPackageInstaller(packageName)) {
            Log.d(TAG, "BLOCK: Package installer ($packageName)")
            return Decision.BLOCK
        }

        // 8. Explicitly block Recent Apps / Task Switcher UI
        if (isRecentAppsUI(className)) {
            Log.d(TAG, "BLOCK: Recent Apps UI ($className)")
            return Decision.BLOCK
        }

        // 9. Always-allowed list (e.g. user-configured Phone, Messages)
        if (FocusModeManager.alwaysAllowedApps.contains(packageName)) {
            Log.d(TAG, "ALLOW: Always-allowed app")
            return Decision.ALLOW
        }

        // 10. User-selected allowed apps for this session
        if (FocusModeManager.allowedApps.contains(packageName)) {
            Log.d(TAG, "ALLOW: User-selected allowed app ($packageName)")
            return Decision.ALLOW
        }

        // 11. Non-launchable system packages (SystemUI, Play Services, background processes) are allowed
        if (isNonLaunchableSystemPackage(packageName)) {
            Log.d(TAG, "ALLOW: Non-launchable system package ($packageName)")
            return Decision.ALLOW
        }

        // 12. Everything else is blocked
        Log.d(TAG, "BLOCK: Non-allowed package ($packageName)")
        DiagnosticsLogger.appBlocked(packageName)
        return Decision.BLOCK
    }

    // ── Private Helpers ──────────────────────────────────────────────────────

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
    private fun isCriticalSystemInfrastructure(packageName: String): Boolean {
        // Check against our comprehensive whitelist
        if (CRITICAL_SYSTEM_PACKAGES.contains(packageName)) return true

        // Check prefix-based patterns for vendor-specific packages
        val lower = packageName.lowercase(Locale.ROOT)
        for (prefix in CRITICAL_SYSTEM_PREFIXES) {
            if (lower.startsWith(prefix)) return true
        }

        return false
    }

    private fun isLauncherPackage(packageName: String): Boolean {
        if (launcherPackages.contains(packageName)) return true
        val lower = packageName.lowercase(Locale.ROOT)
        return KNOWN_LAUNCHERS.contains(lower) ||
            lower.endsWith(".launcher") ||
            lower.contains("launcher") ||
            lower.endsWith(".home")
    }

    private fun isAssistantPackage(packageName: String): Boolean {
        // Hard-code Google assistant (most common)
        if (packageName == "com.google.android.googlequicksearchbox") return true
        if (packageName == "com.samsung.android.bixby.service") return true
        if (packageName == "com.samsung.android.bixbyvision.framework") return true
        if (packageName == "com.microsoft.cortana") return true
        // Read the system assistant setting
        return try {
            val assistantSetting = android.provider.Settings.Secure.getString(
                context.contentResolver,
                "assistant"
            )
            if (!assistantSetting.isNullOrBlank()) {
                val pkg = assistantSetting.split("/").firstOrNull()
                pkg == packageName
            } else false
        } catch (_: Exception) {
            false
        }
    }

    private fun isRecentAppsUI(className: String?): Boolean {
        if (className.isNullOrBlank()) return false
        val lower = className.lowercase(Locale.ROOT)
        return lower.contains("recents") ||
               lower.contains("recentapps") ||
               lower.contains("taskswitcher") ||
               lower.contains("overview")
    }

    private fun isSettingsPackage(packageName: String): Boolean {
        val lower = packageName.lowercase(Locale.ROOT)
        return lower.contains("settings") ||
               lower == "com.samsung.android.lool" // Samsung Device Care
    }

    private fun isPackageInstaller(packageName: String): Boolean {
        val lower = packageName.lowercase(Locale.ROOT)
        return lower.contains("packageinstaller") ||
               lower == "com.android.packageinstaller" ||
               lower == "com.google.android.packageinstaller"
    }

    /**
     * Checks if the package is a background/telephony system service rather than a user-facing
     * launchable application (like Chrome or YouTube) which should be subject to allowed-apps whitelist.
     */
    private fun isNonLaunchableSystemPackage(packageName: String): Boolean {
        // Explicitly allow Google Play Services, Android Framework, and SystemUI
        if (packageName == "com.google.android.gms" ||
            packageName == "android" ||
            packageName.startsWith("com.android.systemui") ||
            packageName.startsWith("com.samsung.android.systemui")
        ) {
            return true
        }

        val appClassifier = AppClassifier(context)
        val isSystem = appClassifier.isSystemPackage(packageName)
        val isLaunchable = appClassifier.isLaunchable(packageName)

        return isSystem && !isLaunchable
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

        private val KNOWN_LAUNCHERS = setOf(
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
        private val CRITICAL_SYSTEM_PACKAGES = setOf(
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
        )
    }
}
