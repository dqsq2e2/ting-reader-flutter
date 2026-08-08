package com.tingreader.client

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.webkit.CookieManager
import androidx.core.view.WindowCompat
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    private var notificationPermissionResult: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        WindowCompat.setDecorFitsSystemWindows(window, false)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "ting_reader/permissions"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestNotificationPermission" -> requestNotificationPermission(result)
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "ting_reader/webview_cookies"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getCookie" -> {
                    val url = call.argument<String>("url")
                    if (url.isNullOrBlank()) {
                        result.error("invalid_url", "Cookie URL is required", null)
                    } else {
                        result.success(CookieManager.getInstance().getCookie(url) ?: "")
                    }
                }
                "setCookie" -> {
                    val url = call.argument<String>("url")
                    val cookie = call.argument<String>("cookie")
                    if (url.isNullOrBlank() || cookie.isNullOrBlank()) {
                        result.error("invalid_cookie", "Cookie URL and value are required", null)
                    } else {
                        CookieManager.getInstance().setCookie(url, cookie) { success ->
                            result.success(success)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(true)
            return
        }
        if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
            return
        }
        if (notificationPermissionResult != null) {
            result.success(false)
            return
        }
        notificationPermissionResult = result
        requestPermissions(
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            NOTIFICATION_PERMISSION_REQUEST
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != NOTIFICATION_PERMISSION_REQUEST) return
        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        notificationPermissionResult?.success(granted)
        notificationPermissionResult = null
    }

    companion object {
        private const val NOTIFICATION_PERMISSION_REQUEST = 4101
    }
}
