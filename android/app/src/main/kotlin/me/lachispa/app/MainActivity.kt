package me.lachispa.app

import android.nfc.NfcAdapter
import android.nfc.cardemulation.CardEmulation
import android.content.ComponentName
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
                    // Force Android to route NFC requests to our service
                    try {
                        val adapter = NfcAdapter.getDefaultAdapter(this)
                        if (adapter != null) {
                            val cardEmulation = CardEmulation.getInstance(adapter)
                            cardEmulation?.setPreferredService(
                                this,
                                ComponentName(this, NfcHceService::class.java)
                            )
                        }
                    } catch (e: Exception) {
                        }
                    result.success(true)
                }
                "clearPayload" -> {
                    // Release preferred service routing
                    try {
                        val adapter = NfcAdapter.getDefaultAdapter(this)
                        if (adapter != null) {
                            val cardEmulation = CardEmulation.getInstance(adapter)
                            cardEmulation?.unsetPreferredService(this)
                        }
                    } catch (e: Exception) {
                        }
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
}
