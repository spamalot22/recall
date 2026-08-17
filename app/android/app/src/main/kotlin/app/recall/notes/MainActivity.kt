package app.recall.notes

import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
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
import java.nio.LongBuffer
import java.security.MessageDigest
import java.util.TimeZone
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val apkInstallerChannel = "app.recall.notes/apk_installer"
    private val deviceChannel = "app.recall.notes/device"
    private val moodModelChannel = "app.recall.notes/mood_model"
    private val moodExecutor = Executors.newSingleThreadExecutor()
    private var moodSession: OrtSession? = null

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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, moodModelChannel).setMethodCallHandler { call, result ->
            when (call.method) {
                "classify" -> classifyMood(call.argument("inputIds"), result)
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        moodExecutor.execute {
            moodSession?.close()
            moodSession = null
        }
        moodExecutor.shutdown()
        super.onDestroy()
    }

    private fun classifyMood(rawInputIds: Any?, result: MethodChannel.Result) {
        val rows = rawInputIds as? List<*>
        if (rows.isNullOrEmpty() || rows.size > 2) {
            result.error("invalid_input", "One or two mood model inputs are required.", null)
            return
        }

        val inputIds = try {
            rows.map { rawRow ->
                val row = rawRow as? List<*>
                    ?: throw IllegalArgumentException("Mood model input must be a list.")
                if (row.size !in 2..64) {
                    throw IllegalArgumentException("Mood model input length is invalid.")
                }
                row.map { rawValue ->
                    val value = (rawValue as? Number)?.toLong()
                        ?: throw IllegalArgumentException("Mood model token is invalid.")
                    if (value !in 0..50264) {
                        throw IllegalArgumentException("Mood model token is out of range.")
                    }
                    value
                }
            }
        } catch (error: IllegalArgumentException) {
            result.error("invalid_input", error.message, null)
            return
        }

        moodExecutor.execute {
            try {
                val output = runMoodModel(inputIds)
                runOnUiThread { result.success(output) }
            } catch (_: Exception) {
                runOnUiThread {
                    result.error("inference_failed", "On-device mood analysis failed.", null)
                }
            }
        }
    }

    private fun runMoodModel(inputRows: List<List<Long>>): List<List<Double>> {
        val sequenceLength = inputRows.maxOf { it.size }
        val flattenedIds = LongArray(inputRows.size * sequenceLength) { 1 }
        val attentionMask = LongArray(flattenedIds.size)
        inputRows.forEachIndexed { rowIndex, row ->
            row.forEachIndexed { columnIndex, token ->
                val offset = rowIndex * sequenceLength + columnIndex
                flattenedIds[offset] = token
                attentionMask[offset] = 1
            }
        }

        val environment = OrtEnvironment.getEnvironment()
        val shape = longArrayOf(inputRows.size.toLong(), sequenceLength.toLong())
        OnnxTensor.createTensor(environment, LongBuffer.wrap(flattenedIds), shape).use { idsTensor ->
            OnnxTensor.createTensor(environment, LongBuffer.wrap(attentionMask), shape).use { maskTensor ->
                val inputs = mapOf(
                    "input_ids" to idsTensor,
                    "attention_mask" to maskTensor,
                )
                getMoodSession(environment).run(inputs).use { outputs ->
                    @Suppress("UNCHECKED_CAST")
                    val logits = outputs[0].value as? Array<FloatArray>
                        ?: throw IllegalStateException("Mood model output type is invalid.")
                    if (logits.size != inputRows.size || logits.any { it.size != 28 }) {
                        throw IllegalStateException("Mood model output shape is invalid.")
                    }
                    return logits.map { row -> row.map { it.toDouble() } }
                }
            }
        }
    }

    private fun getMoodSession(environment: OrtEnvironment): OrtSession {
        moodSession?.let { return it }
        val model = assets.open(MOOD_MODEL_ASSET).use { it.readBytes() }
        val digest = MessageDigest.getInstance("SHA-256")
            .digest(model)
            .joinToString("") { byte -> "%02x".format(byte) }
        if (digest != MOOD_MODEL_SHA256) {
            throw SecurityException("Bundled mood model integrity check failed.")
        }

        val session = OrtSession.SessionOptions().use { options ->
            options.setInterOpNumThreads(1)
            options.setIntraOpNumThreads(2)
            options.setOptimizationLevel(OrtSession.SessionOptions.OptLevel.ALL_OPT)
            environment.createSession(model, options)
        }
        moodSession = session
        return session
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
        val archiveVersionCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            archiveInfo.longVersionCode
        } else {
            @Suppress("DEPRECATION")
            archiveInfo.versionCode.toLong()
        }
        val installedVersionCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            installedInfo.longVersionCode
        } else {
            @Suppress("DEPRECATION")
            installedInfo.versionCode.toLong()
        }
        if (archiveVersionCode <= installedVersionCode) {
            return "Downloaded APK is not newer than the installed version."
        }

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

    companion object {
        private const val MOOD_MODEL_ASSET =
            "flutter_assets/assets/models/recall_goemotions_v2.onnx"
        private const val MOOD_MODEL_SHA256 =
            "594ac3bf3c82e2ea187e50982ea2f811ede5377eaad0c8ad23bc04ee8a2486c6"
    }
}
