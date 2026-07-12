package com.personal.phone_addiction_controller

import android.content.Context

class AllowedAppsManager(private val context: Context) {

    private val classifier = AppClassifier(context)

    fun updateAllowedApps(allowed: Collection<String>, alwaysAllowed: Collection<String>) {
        FocusModeManager.allowedApps = allowed.toSet()
        FocusModeManager.alwaysAllowedApps = alwaysAllowed.toSet()
    }

    fun updateSessionAllowedApps(packageNames: Collection<String>) {
        FocusModeManager.allowedApps = packageNames.toSet()
    }

    fun getSessionAllowedApps(): Set<String> {
        return FocusModeManager.allowedApps
    }

    fun getAlwaysAllowedApps(): Set<String> {
        return FocusModeManager.alwaysAllowedApps
    }

    fun getEffectiveAllowedPackages(): Set<String> {
        return buildSet {
            addAll(getSessionAllowedApps())
            addAll(getAlwaysAllowedApps())
            add(context.packageName)
        }
    }

    fun isUserInstalledApp(packageName: String): Boolean {
        return classifier.isUserInstalledApp(packageName)
    }

    fun isLauncherPackage(packageName: String): Boolean {
        return classifier.isLauncherPackage(packageName)
    }

    fun isAssistantPackage(packageName: String): Boolean {
        if (packageName == "com.google.android.googlequicksearchbox") return true
        try {
            val assistantSetting = android.provider.Settings.Secure.getString(
                context.contentResolver,
                "assistant"
            )
            if (!assistantSetting.isNullOrBlank()) {
                val pkg = assistantSetting.split("/").firstOrNull()
                if (pkg == packageName) return true
            }
        } catch (e: Exception) {
            // Ignore
        }
        return false
    }

    fun isClassifierSystemPackage(packageName: String): Boolean {
        return classifier.isSystemPackage(packageName)
    }

    fun isAlwaysAllowed(packageName: String): Boolean {
        return packageName in getAlwaysAllowedApps()
    }

    fun isUserAllowed(packageName: String): Boolean {
        return packageName in getSessionAllowedApps()
    }

    fun isAllowed(packageName: String): Boolean {
        if (packageName.isBlank()) return true
        if (packageName == context.packageName) return true
        if (isUserAllowed(packageName)) return true
        if (isAlwaysAllowed(packageName)) return true
        if (isLauncherPackage(packageName)) return false
        if (isAssistantPackage(packageName)) return false
        if (isClassifierSystemPackage(packageName)) return true
        return false
    }
}