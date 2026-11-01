package com.personal.phone_addiction_controller

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import android.view.accessibility.AccessibilityNodeInfo
import java.util.Locale

/**
 * Best-effort screen guard for Detox's own removal and deactivation screens.
 *
 * This is not an Android security boundary: users can disable Accessibility,
 * force-stop the app, or use other system paths to remove it.
 *
 * The admin password itself is verified in Flutter; on success Flutter opens a
 * short unlock window with [unlock]. The window is stored as an absolute time so
 * it survives process death, and closes itself.
 */
object TamperGuard {
    private const val TAG = "TamperGuard"
    private const val PREFS_NAME = "TamperGuardPrefs"
    private const val KEY_ENABLED = "protectionEnabled"
    private const val KEY_UNLOCKED_UNTIL = "unlockedUntil"
    private const val MAX_NODES = 400

    private lateinit var prefs: SharedPreferences

    fun init(context: Context) {
        if (!::prefs.isInitialized) {
            prefs = context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        }
    }

    var isProtectionEnabled: Boolean
        get() = ::prefs.isInitialized && prefs.getBoolean(KEY_ENABLED, false)
        set(value) {
            if (::prefs.isInitialized) prefs.edit().putBoolean(KEY_ENABLED, value).apply()
        }

    private var unlockedUntil: Long
        get() = if (::prefs.isInitialized) prefs.getLong(KEY_UNLOCKED_UNTIL, 0L) else 0L
        set(value) {
            if (::prefs.isInitialized) prefs.edit().putLong(KEY_UNLOCKED_UNTIL, value).apply()
        }

    val isUnlocked: Boolean get() = System.currentTimeMillis() < unlockedUntil

    /** Remaining unlock time in ms (0 when locked). */
    val unlockRemainingMs: Long get() = (unlockedUntil - System.currentTimeMillis()).coerceAtLeast(0L)

    fun unlock(durationMs: Long) {
        unlockedUntil = System.currentTimeMillis() + durationMs.coerceIn(0L, MAX_UNLOCK_MS)
        Log.d(TAG, "Protection unlocked for ${durationMs / 1000}s")
    }

    fun lock() {
        unlockedUntil = 0L
    }

    /** True when a screen of [packageName] must be dismissed because it exposes our app's controls. */
    fun shouldBlock(
        context: Context,
        packageName: String,
        root: AccessibilityNodeInfo?
    ): Boolean {
        if (!isProtectionEnabled || isUnlocked) return false
        if (packageName == context.packageName) return false

        val isInstaller = isPackageInstaller(packageName)
        val isSettings = isSettingsPackage(packageName)
        if (!isInstaller && !isSettings) return false
        if (root == null) return false

        val label = appLabel(context)
        val text = collectText(root)
        val identifiesApp = text.contains(label) ||
            text.contains(context.packageName.lowercase(Locale.ROOT))
        if (!identifiesApp) return false

        return DANGEROUS_ACTION_TEXT.any { text.contains(it) }
    }

    private fun appLabel(context: Context): String =
        context.applicationInfo.loadLabel(context.packageManager).toString().lowercase(Locale.ROOT)

    private fun isPackageInstaller(packageName: String): Boolean {
        val lower = packageName.lowercase(Locale.ROOT)
        return lower.contains("packageinstaller")
    }

    private fun isSettingsPackage(packageName: String): Boolean {
        val lower = packageName.lowercase(Locale.ROOT)
        return lower == "com.android.settings" ||
            lower.startsWith("com.samsung.android.settings") ||
            lower.endsWith(".settings") ||
            lower == "com.samsung.android.app.settings" ||
            lower == "com.samsung.android.lool"
    }

    /** Lower-cased text/content descriptions of the window, bounded in size. */
    private fun collectText(root: AccessibilityNodeInfo): String {
        val out = StringBuilder()
        var visited = 0
        fun walk(node: AccessibilityNodeInfo?, depth: Int) {
            if (node == null || visited >= MAX_NODES || depth > 25) return
            visited++
            node.text?.let { out.append(it).append('\n') }
            node.contentDescription?.let { out.append(it).append('\n') }
            for (i in 0 until node.childCount) {
                walk(node.getChild(i), depth + 1)
            }
        }
        walk(root, 0)
        return out.toString().lowercase(Locale.ROOT)
    }

    private const val MAX_UNLOCK_MS = 30 * 60 * 1000L

    private val DANGEROUS_ACTION_TEXT = listOf(
        "uninstall",
        "force stop",
        "deactivate",
        "clear data",
        "clear storage",
        "turn off",
        "stop using"
    )
}
