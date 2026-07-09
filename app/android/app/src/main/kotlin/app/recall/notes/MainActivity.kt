package app.recall.notes

import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest
import java.util.TimeZone

class MainActivity : FlutterActivity() {
    private val apkInstallerChannel = "app.recall.notes/apk_installer"
    private val deviceChannel = "app.recall.notes/device"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, apkInstallerChannel).setMethodCallHandler { call, result ->
            when (call.method) {
                "installApk" -> {
                    val path = call.argument<String>("path")
                    if (path.isNullOrBlank()) {
                        result.error("invalid_path", "APK path is required.", null)
                        return@setMethodCallHandler
                    }

                    installApk(path, result)
                }

                "openInstallPermissionSettings" -> {
                    openInstallPermissionSettings()
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, deviceChannel).setMethodCallHandler { call, result ->
            when (call.method) {
                "localTimezone" -> result.success(TimeZone.getDefault().id)
                else -> result.notImplemented()
            }
        }
    }

    private fun installApk(path: String, result: MethodChannel.Result) {
        val apk = File(path)
        if (!apk.exists() || !apk.isFile) {
            result.error("missing_apk", "Downloaded APK was not found.", null)
            return
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && !packageManager.canRequestPackageInstalls()) {
            result.error("permission_required", "Install unknown apps permission is required.", null)
            return
        }

        val validationError = validateApk(apk)
        if (validationError != null) {
            result.error("invalid_apk", validationError, null)
            return
        }

        val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", apk)
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }

        try {
            startActivity(intent)
            result.success(null)
        } catch (error: Exception) {
            result.error("install_failed", error.message ?: "Could not open Android package installer.", null)
        }
    }

    private fun validateApk(apk: File): String? {
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            PackageManager.GET_SIGNING_CERTIFICATES
        } else {
            @Suppress("DEPRECATION")
            PackageManager.GET_SIGNATURES
        }

        @Suppress("DEPRECATION")
        val archiveInfo = packageManager.getPackageArchiveInfo(apk.path, flags)
            ?: return "Downloaded APK could not be inspected."

        if (archiveInfo.packageName != packageName) {
            return "Downloaded APK package does not match Recall."
        }

        val installedInfo = packageManager.getPackageInfo(packageName, flags)
        val archiveDigests = signingCertificateDigests(archiveInfo)
        val installedDigests = signingCertificateDigests(installedInfo)

        if (archiveDigests.isEmpty() || installedDigests.isEmpty()) {
            return "Downloaded APK signing certificate could not be inspected."
        }

        if (archiveDigests.none { installedDigests.contains(it) }) {
            return "Downloaded APK signing certificate does not match this app."
        }

        return null
    }

    private fun signingCertificateDigests(packageInfo: PackageInfo): Set<String> {
        val signatures = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val signingInfo = packageInfo.signingInfo ?: return emptySet()
            if (signingInfo.hasMultipleSigners()) {
                signingInfo.apkContentsSigners
            } else {
                signingInfo.signingCertificateHistory
            }
        } else {
            @Suppress("DEPRECATION")
            packageInfo.signatures ?: return emptySet()
        }

        val digest = MessageDigest.getInstance("SHA-256")
        return signatures.map { signature ->
            digest.digest(signature.toByteArray()).joinToString("") { byte ->
                "%02x".format(byte)
            }
        }.toSet()
    }

    private fun openInstallPermissionSettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val intent = Intent(
                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                Uri.parse("package:$packageName")
            ).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            return
        }

        val intent = Intent(Settings.ACTION_SECURITY_SETTINGS).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
    }
}
