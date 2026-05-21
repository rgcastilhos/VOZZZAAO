package com.example.voz_comando

import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "voz_comando/phone_control")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isAccessibilityEnabled" -> {
                        result.success(PhoneAccessibilityService.isRunning())
                    }

                    "pressBack" -> {
                        val times = call.argument<Int>("times") ?: 1
                        result.success(PhoneAccessibilityService.pressBack(times))
                    }

                    "openAccessibilitySettings" -> {
                        startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                        result.success(null)
                    }

                    "getInstalledApps" -> {
                        result.success(getInstalledApps())
                    }

                    "openApp" -> {
                        val packageName = call.argument<String>("package")
                        result.success(openApp(packageName))
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun getInstalledApps(): List<Map<String, String>> {
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val activities = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.queryIntentActivities(
                intent,
                PackageManager.ResolveInfoFlags.of(0),
            )
        } else {
            @Suppress("DEPRECATION")
            packageManager.queryIntentActivities(intent, 0)
        }

        return activities
            .mapNotNull { info ->
                val packageName = info.activityInfo?.packageName ?: return@mapNotNull null
                val label = info.loadLabel(packageManager)?.toString()?.trim()
                if (label.isNullOrEmpty()) return@mapNotNull null
                mapOf("name" to label, "package" to packageName)
            }
            .distinctBy { it["package"] }
            .sortedBy { it["name"]?.lowercase() }
    }

    private fun openApp(packageName: String?): Boolean {
        if (packageName.isNullOrBlank()) return false
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName) ?: return false
        launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(launchIntent)
        return true
    }
}
