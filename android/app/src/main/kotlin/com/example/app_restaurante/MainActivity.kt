package com.example.app_restaurante

import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.costafoods.app/kiosk"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "startKiosk") {
                try {
                    val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
                    val adminName = ComponentName(this, MyDeviceAdminReceiver::class.java)
                    
                    // Verifica se somos Donos do Dispositivo (Admin)
                    if (dpm.isDeviceOwnerApp(packageName)) {
                        // OBRIGATÓRIO: Define este app como o único permitido no modo Kiosk
                        dpm.setLockTaskPackages(adminName, arrayOf(packageName))
                        startLockTask() 
                    } else {
                        // Fallback se não for admin (apenas fixa a tela, mas permite sair)
                        startLockTask()
                    }
                    result.success(null)
                } catch (e: Exception) {
                    result.error("ERROR", "Erro ao iniciar Kiosk: ${e.message}", null)
                }
            } else if (call.method == "stopKiosk") {
                try {
                    stopLockTask()
                    result.success(null)
                } catch (e: Exception) {
                    result.error("ERROR", "Erro ao parar Kiosk", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
    
    // Garante que o app tente travar assim que abrir a janela
    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) {
            // Opcional: Tenta travar novamente se perder o foco
            // descomente a linha abaixo se quiser forçar agressivamente
            // startLockTask() 
        }
    }
}