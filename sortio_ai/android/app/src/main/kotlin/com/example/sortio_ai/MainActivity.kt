package com.example.sortio_ai

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileNotFoundException
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val io = Executors.newSingleThreadExecutor()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "sortio/model")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "installBundledModel" -> {
                        val asset = call.argument<String>("asset")!!
                        val dest = call.argument<String>("dest")!!
                        io.execute {
                            try {
                                val installed = installBundledModel(asset, File(dest))
                                runOnUiThread { result.success(installed) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("install_failed", e.message, null) }
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Streams the model out of the APK into app-private storage, once.
     * Returns false when the APK has no bundled model (dev builds).
     * Writes to a temp file and renames, so a killed app never leaves a
     * truncated model behind.
     */
    private fun installBundledModel(asset: String, dest: File): Boolean {
        val expected = try {
            assets.openFd(asset).use { it.length }
        } catch (e: FileNotFoundException) {
            return false
        }
        if (dest.exists() && dest.length() == expected) return true

        dest.parentFile?.mkdirs()
        val tmp = File(dest.path + ".part")
        assets.open(asset).use { input ->
            tmp.outputStream().use { output -> input.copyTo(output, 1 shl 20) }
        }
        if (tmp.length() != expected) {
            tmp.delete()
            throw IllegalStateException("Model copy incomplete")
        }
        if (!tmp.renameTo(dest)) {
            tmp.delete()
            throw IllegalStateException("Could not move model into place")
        }
        return true
    }
}
