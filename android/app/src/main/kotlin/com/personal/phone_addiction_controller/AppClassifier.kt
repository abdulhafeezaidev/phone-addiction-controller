package com.personal.phone_addiction_controller

import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.Build
import java.util.Locale

enum class AppType {
    SYSTEM_APP,
    UPDATED_SYSTEM_APP,
    USER_INSTALLED_APP
}

class AppClassifier(private val context: Context) {

    private val packageManager: PackageManager = context.packageManager

    private val launcherPackages: Set<String> by lazy {
        val homeIntent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
        }
        val resolveInfos = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.queryIntentActivities(
                homeIntent,
                PackageManager.ResolveInfoFlags.of(0L)
            )
        } else {
            @Suppress("DEPRECATION")
            packageManager.queryIntentActivities(homeIntent, 0)
        }
        resolveInfos.mapNotNull { it.activityInfo?.packageName }.toSet()
    }

    private val launchablePackages: Set<String> by lazy {
        val mainIntent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_LAUNCHER)
        }
        val resolveInfos = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.queryIntentActivities(
                mainIntent,
                PackageManager.ResolveInfoFlags.of(0L)
            )
        } else {
            @Suppress("DEPRECATION")
            packageManager.queryIntentActivities(mainIntent, 0)
        }
        resolveInfos.mapNotNull { it.activityInfo?.packageName }.toSet()
    }

    fun getAppType(packageName: String): AppType {
        if (packageName.isBlank()) return AppType.SYSTEM_APP

        val appInfo = getApplicationInfoOrNull(packageName) ?: return AppType.SYSTEM_APP
        val flags = appInfo.flags

        val isSystem = (flags and ApplicationInfo.FLAG_SYSTEM) != 0
        val isUpdatedSystem = (flags and ApplicationInfo.FLAG_UPDATED_SYSTEM_APP) != 0

        return when {
            isUpdatedSystem -> AppType.UPDATED_SYSTEM_APP
            isSystem -> AppType.SYSTEM_APP
            else -> AppType.USER_INSTALLED_APP
        }
    }

    fun isUserInstalledApp(packageName: String): Boolean {
        if (packageName.isBlank() || packageName == context.packageName) return false

        // System and updated system apps are not user installed apps
        val appType = getAppType(packageName)
        if (appType != AppType.USER_INSTALLED_APP) return false

        // Must be a launchable application
        if (!isLaunchable(packageName)) return false

        // Launchers are handled separately
        if (isLauncherPackage(packageName)) return false

        return true
    }

    fun isSystemPackage(packageName: String): Boolean {
        if (packageName.isBlank()) return true
        if (packageName == context.packageName) return false
        if (isLauncherPackage(packageName)) return false

        val appType = getAppType(packageName)
        return appType == AppType.SYSTEM_APP || appType == AppType.UPDATED_SYSTEM_APP
    }

    fun isLauncherPackage(packageName: String): Boolean {
        if (packageName.isBlank()) return false
        if (launcherPackages.contains(packageName)) return true
        val lower = packageName.lowercase(Locale.ROOT)
        return FocusPolicyEngine.KNOWN_LAUNCHERS.contains(lower) ||
            lower.endsWith(".launcher") ||
            lower.contains("launcher") ||
            lower.endsWith(".home")
    }

    fun isLaunchable(packageName: String): Boolean {
        return launchablePackages.contains(packageName)
    }

    private fun getApplicationInfoOrNull(packageName: String): ApplicationInfo? {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                packageManager.getApplicationInfo(
                    packageName,
                    PackageManager.ApplicationInfoFlags.of(0L)
                )
            } else {
                @Suppress("DEPRECATION")
                packageManager.getApplicationInfo(packageName, 0)
            }
        } catch (_: PackageManager.NameNotFoundException) {
            null
        }
    }
}
