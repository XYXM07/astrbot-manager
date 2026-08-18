package dev.astr.astrbot_manager

import android.os.Build
import android.os.Bundle
import android.view.View
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "astr/frame_rate"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Block the Android autofill framework app-wide so the system never
        // draws its yellow autofill highlight over our text fields.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            window.decorView.importantForAutofill =
                View.IMPORTANT_FOR_AUTOFILL_NO_EXCLUDE_DESCENDANTS
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "setFrameRate") {
                    val fps = (call.arguments as? Number)?.toInt() ?: 0
                    runOnUiThread { applyFrameRate(fps) }
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }

    // fps: 30 / 60 / 120; fps <= 0 means unlimited (system default).
    // preferredRefreshRate is deprecated since API 30 but remains the only
    // public app-window API and is honored by MIUI to unlock high refresh rate.
    private fun applyFrameRate(fps: Int) {
        try {
            @Suppress("DEPRECATION")
            window.attributes = window.attributes.apply {
                preferredRefreshRate = fps.toFloat()
            }
        } catch (_: Exception) {
            // ignore: some devices may not support the requested frame rate
        }
    }
}