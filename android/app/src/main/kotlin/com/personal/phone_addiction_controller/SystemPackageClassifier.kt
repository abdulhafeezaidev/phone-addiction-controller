package com.personal.phone_addiction_controller

import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import java.util.Locale

enum class PackageCategory {
    ANDROID_SYSTEM,
    SAMSUNG_SYSTEM,
    GOOGLE_CORE_SERVICES,
    USER_INSTALLED_APPLICATION
}

data class PackageClassification(
    val category: PackageCategory,
    val isLauncher: Boolean,
    val usesSystemFlags: Boolean
)

class SystemPackageClassifier(private val context: Context) {

    private val packageManager = context.packageManager

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

    fun classify(packageName: String): PackageClassification {
        if (packageName.isBlank()) {
            return PackageClassification(PackageCategory.USER_INSTALLED_APPLICATION, false, false)
        }

        val isLauncher = isLauncherPackage(packageName)
        val appInfo = getApplicationInfoOrNull(packageName)
        val flags = appInfo?.flags ?: 0
        val usesSystemFlags = flags and ApplicationInfo.FLAG_SYSTEM != 0 ||
            flags and ApplicationInfo.FLAG_UPDATED_SYSTEM_APP != 0

        if (isLauncher) {
            return PackageClassification(PackageCategory.USER_INSTALLED_APPLICATION, true, usesSystemFlags)
        }

        val normalizedPackage = packageName.lowercase(Locale.ROOT)
        val manufacturer = Build.MANUFACTURER.lowercase(Locale.ROOT)
        val metadata = appInfo?.metaData

        val category = when {
            isGoogleCoreService(normalizedPackage, metadata) -> PackageCategory.GOOGLE_CORE_SERVICES
            isSamsungSystemPackage(normalizedPackage, manufacturer, metadata) -> PackageCategory.SAMSUNG_SYSTEM
            isAndroidSystemPackage(normalizedPackage, metadata) || usesSystemFlags -> PackageCategory.ANDROID_SYSTEM
            else -> PackageCategory.USER_INSTALLED_APPLICATION
        }

        return PackageClassification(category, false, usesSystemFlags)
    }

    fun isSystemPackage(packageName: String): Boolean {
        return classify(packageName).category != PackageCategory.USER_INSTALLED_APPLICATION
    }

    fun isCriticalSystemPackage(packageName: String): Boolean {
        val classification = classify(packageName)
        return classification.category != PackageCategory.USER_INSTALLED_APPLICATION && !classification.isLauncher
    }

    fun isLauncherPackage(packageName: String): Boolean {
        if (packageName.isBlank()) return false
        if (launcherPackages.contains(packageName)) return true
        val lower = packageName.lowercase(Locale.ROOT)
        return commonLaunchers.contains(lower) ||
            lower.endsWith(".launcher") ||
            lower.contains("launcher") ||
            lower.endsWith(".home") ||
            lower.contains("recents")
    }

    private fun getApplicationInfoOrNull(packageName: String): ApplicationInfo? {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                packageManager.getApplicationInfo(
                    packageName,
                    PackageManager.ApplicationInfoFlags.of(PackageManager.GET_META_DATA.toLong())
                )
            } else {
                @Suppress("DEPRECATION")
                packageManager.getApplicationInfo(packageName, PackageManager.GET_META_DATA)
            }
        } catch (_: PackageManager.NameNotFoundException) {
            null
        }
    }

    private fun isAndroidSystemPackage(packageName: String, metadata: Bundle?): Boolean {
        if (packageName in androidSystemPackages) return true

        return metadata?.let { bundle ->
            bundle.containsKey("android.system.package") ||
                bundle.containsKey("android.permission.CAN_INSTALL_PACKAGES")
        } ?: false
    }

    private fun isSamsungSystemPackage(
        packageName: String,
        manufacturer: String,
        metadata: Bundle?
    ): Boolean {
        if (packageName.startsWith("com.samsung.") || packageName.startsWith("com.sec.")) return true

        return manufacturer.contains("samsung") &&
            (packageName.startsWith("com.samsung.") || packageName.startsWith("com.sec.") ||
                metadata?.containsKey("com.samsung.android.feature") == true)
    }

    private fun isGoogleCoreService(packageName: String, metadata: Bundle?): Boolean {
        if (packageName in googleCorePackages) return true

        return metadata?.containsKey("com.google.android.gms.version") == true ||
            metadata?.containsKey("com.google.android.paid_mandatory") == true
    }

    companion object {
        private val androidSystemPackages = setOf(
            "com.android.systemui",
            "com.android.settings",
            "com.android.phone",
            "com.android.contacts",
            "com.android.camera",
            "com.android.deskclock",
            "com.android.calculator2",
            "com.android.documentsui",
            "com.android.bluetooth",
            "com.android.permissioncontroller",
            "com.android.packageinstaller",
            "com.android.providers.downloads",
            "com.android.keychain",
            "com.android.emergency",
            "com.android.server.telecom",
            "com.android.vending"
        )

        private val googleCorePackages = setOf(
            "com.google.android.gms",
            "com.google.android.gsf",
            "com.google.android.googlequicksearchbox",
            "com.google.android.apps.nexuslauncher",
            "com.google.android.permissioncontroller",
            "com.android.vending"
        )

        private val commonLaunchers = setOf(
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
            "com.teslacoilsw.launcher"
        )
    }
}