package com.example.cliente_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity: FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ✅ Registrar el plugin de optimización de batería
        BatteryOptimizationPlugin(this).registerWith(flutterEngine)
    }
}