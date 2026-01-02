package com.example.cliente_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity: FlutterActivity() {

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannel()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ✅ Registrar el plugin de optimización de batería
        BatteryOptimizationPlugin(this).registerWith(flutterEngine)
    }

    private fun createNotificationChannel() {
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            val channelId = "ada_background_service"
            val channelName = "AdaApp Background Service"
            val channelDescription = "Canal para servicio en segundo plano de AdaApp"
            val importance = android.app.NotificationManager.IMPORTANCE_LOW
            
            val channel = android.app.NotificationChannel(channelId, channelName, importance).apply {
                description = channelDescription
            }
            
            val notificationManager: android.app.NotificationManager =
                getSystemService(android.content.Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }
}