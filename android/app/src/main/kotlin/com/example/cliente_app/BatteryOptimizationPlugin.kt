package com.example.cliente_app

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.annotation.NonNull
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class BatteryOptimizationPlugin(private val context: Context) : MethodCallHandler {

    companion object {
        private const val CHANNEL = "battery_optimization"
        private const val REQUEST_IGNORE_BATTERY_OPTIMIZATION = 1000
    }

    fun registerWith(flutterEngine: FlutterEngine) {
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "isIgnoringBatteryOptimizations" -> {
                result.success(isIgnoringBatteryOptimizations())
            }
            "requestIgnoreBatteryOptimizations" -> {
                requestIgnoreBatteryOptimizations(result)
            }
            "openBatteryOptimizationSettings" -> {
                result.success(openBatteryOptimizationSettings())
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    /**
     * Verifica si la app está en la whitelist de optimización de batería
     */
    private fun isIgnoringBatteryOptimizations(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            powerManager.isIgnoringBatteryOptimizations(context.packageName)
        } else {
            // En versiones anteriores a Android 6.0, no hay optimización de batería
            true
        }
    }

    /**
     * Solicita al usuario que deshabilite la optimización de batería
     */
    private fun requestIgnoreBatteryOptimizations(result: Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                if (!isIgnoringBatteryOptimizations()) {
                    val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                        data = Uri.parse("package:${context.packageName}")
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    }

                    if (intent.resolveActivity(context.packageManager) != null) {
                        context.startActivity(intent)

                        // Verificar después de un pequeño delay si el usuario aceptó
                        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                            result.success(isIgnoringBatteryOptimizations())
                        }, 2000) // 2 segundos de delay
                    } else {
                        // Si no se puede abrir la configuración específica, abrir configuraciones generales
                        openBatteryOptimizationSettings()
                        result.success(false)
                    }
                } else {
                    result.success(true)
                }
            } catch (e: Exception) {
                result.error("REQUEST_FAILED", "Error solicitando deshabilitar optimización: ${e.message}", null)
            }
        } else {
            // En versiones anteriores a Android 6.0, no hay optimización de batería
            result.success(true)
        }
    }

    /**
     * Abre la configuración de optimización de batería
     */
    private fun openBatteryOptimizationSettings(): Boolean {
        return try {
            val intent = when {
                // Android 6.0+
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.M -> {
                    Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    }
                }
                else -> {
                    Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                        data = Uri.parse("package:${context.packageName}")
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    }
                }
            }

            if (intent.resolveActivity(context.packageManager) != null) {
                context.startActivity(intent)
                true
            } else {
                // Fallback: abrir configuración general
                val fallbackIntent = Intent(Settings.ACTION_SETTINGS).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                context.startActivity(fallbackIntent)
                false
            }
        } catch (e: Exception) {
            false
        }
    }
}