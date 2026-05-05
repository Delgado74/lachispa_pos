package me.lachispa.app

import android.nfc.NfcAdapter
import android.nfc.cardemulation.CardEmulation
import android.util.Log
import com.novice.lachispa.NfcHceService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "lachispa/nfc_hce"
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setPayload" -> {
                    val payload = call.argument<ByteArray>("payload")
                    NfcHceService.ndefPayload = payload
                    Log.d("MainActivity", "Payload set: ${payload?.size} bytes")
                    
                    // Force Android to route NFC requests to our service
                    // instead of manufacturer services (Xiaomi Mi Share, etc.)
                    try {
                        val adapter = NfcAdapter.getDefaultAdapter(this)
                        if (adapter != null) {
                            val cardEmulation = CardEmulation.getInstance(adapter)
                            cardEmulation?.setPreferredService(
                                this,
                                android.content.ComponentName(this, NfcHceService::class.java)
                            )
                        }
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                    result.success(true)
                }
                "clearPayload" -> {
                    NfcHceService.ndefPayload = null
                    
                    // Release preferred service routing
                    try {
                        val adapter = NfcAdapter.getDefaultAdapter(this)
                        if (adapter != null) {
                            val cardEmulation = CardEmulation.getInstance(adapter)
                            cardEmulation?.unsetPreferredService(this)
                        }
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
}
