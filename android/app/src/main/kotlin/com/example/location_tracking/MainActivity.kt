package com.example.location_tracking

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.yourcompany.yourapp/foreground_service"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startService" -> {
                        val serviceIntent = Intent(this, LocationService::class.java)
                        startService(serviceIntent)
                        result.success("Service started")
                    }
                    "stopService" -> {
                        val serviceIntent = Intent(this, LocationService::class.java)
                        stopService(serviceIntent)
                        result.success("Service stopped")
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
