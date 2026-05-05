package com.novice.lachispa

import android.nfc.NdefMessage
import android.nfc.NdefRecord
import android.nfc.cardemulation.HostApduService
import android.content.Intent
import android.os.Bundle
import android.util.Log
import java.io.*

class NfcHceService : HostApduService() {

    private val TAG = "NfcHceService"
    
    // APDU commands
    private val APDU_SELECT_STANDARD = byteArrayOf(
        0x00.toByte(), // CLA
        0xA4.toByte(), // INS
        0x04.toByte(), // P1
        0x00.toByte(), // P2
        0x07.toByte(), // Lc
        0xD2.toByte(), 0x76.toByte(), 0x00.toByte(),
        0x00.toByte(), 0x85.toByte(), 0x01.toByte(), 0x01.toByte(), // NDEF Tag Application
        0x00.toByte()  // Le
    )
    
    private val APDU_SELECT_ELCAJU = byteArrayOf(
        0x00.toByte(), // CLA
        0xA4.toByte(), // INS
        0x04.toByte(), // P1
        0x00.toByte(), // P2
        0x07.toByte(), // Lc
        0xF0.toByte(), 0x45.toByte(), 0x43.toByte(), 0x41.toByte(),
        0x4A.toByte(), 0x55.toByte(), 0x00.toByte(), // ElCaju AID
        0x00.toByte()  // Le
    )
    
    private val CAPABILITY_CONTAINER_OK = byteArrayOf(
        0x00.toByte(), 0xA4.toByte(), 0x00.toByte(), 0x0C.toByte(),
        0x02.toByte(), 0xE1.toByte(), 0x03.toByte()
    )
    
    private val READ_CAPABILITY_CONTAINER = byteArrayOf(
        0x00.toByte(), 0xB0.toByte(), 0x00.toByte(), 0x00.toByte(),
        0x0F.toByte()
    )
    
    private var READ_CAPABILITY_CONTAINER_CHECK = false
    
    private val READ_CAPABILITY_CONTAINER_RESPONSE = byteArrayOf(
        0x00.toByte(), 0x0F.toByte(), // CCLEN
        0x20.toByte(), // Mapping Version 2.0
        0x00.toByte(), 0x3B.toByte(), // MLe
        0x00.toByte(), 0x34.toByte(), // MLc
        0x04.toByte(), // T
        0x06.toByte(), // L
        0xE1.toByte(), 0x04.toByte(), // File ID
        0x00.toByte(), 0xFF.toByte(), // Max NDEF file size
        0x00.toByte(), 0xFF.toByte(),
        0x00.toByte(), // Read access
        0xFF.toByte(), // Write access
        0x90.toByte(), 0x00.toByte()
    )
    
    private val NDEF_SELECT_OK = byteArrayOf(
        0x00.toByte(), 0xA4.toByte(), 0x00.toByte(), 0x0C.toByte(),
        0x02.toByte(), 0xE1.toByte(), 0x04.toByte()
    )
    
    private val NDEF_READ_BINARY = byteArrayOf(
        0x00.toByte(), 0xB0.toByte()
    )
    
    private val NDEF_READ_BINARY_NLEN = byteArrayOf(
        0x00.toByte(), 0xB0.toByte(),
        0x00.toByte(), 0x00.toByte(),
        0x02.toByte()
    )
    
    private val A_OKAY = byteArrayOf(
        0x90.toByte(), 0x00.toByte()
    )
    
    private val A_ERROR = byteArrayOf(
        0x6A.toByte(), 0x82.toByte()
    )
    
    private val NDEF_ID = byteArrayOf(0xE1.toByte(), 0x04.toByte())
    
    // NDEF payload (set from Flutter)
    private var ndefPayload: ByteArray? = null
    
    override fun onCreate() {
        super.onCreate()
        Log.i(TAG, "NfcHceService created")
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.hasExtra("payload") == true) {
            val payload = intent.getByteArrayExtra("payload")
            ndefPayload = payload
            Log.i(TAG, "Payload set: ${payload?.size} bytes")
        }
        return START_REDELIVER_INTENT
    }
    
    override fun processCommandApdu(commandApdu: ByteArray, extras: Bundle?): ByteArray {
        Log.i(TAG, "processCommandApdu() | incoming: ${commandApdu.toHex()}")
        
        // SELECT NDEF Application (either standard or ElCaju AID)
        if (APDU_SELECT_STANDARD.contentEquals(commandApdu) ||
            APDU_SELECT_ELCAJU.contentEquals(commandApdu)) {
            Log.i(TAG, "SELECT AID triggered")
            return A_OKAY
        }
        
        // SELECT Capability Container
        if (CAPABILITY_CONTAINER_OK.contentEquals(commandApdu)) {
            Log.i(TAG, "CAPABILITY_CONTAINER_OK triggered")
            READ_CAPABILITY_CONTAINER_CHECK = false
            return A_OKAY
        }
        
        // READ BINARY (CC)
        if (READ_CAPABILITY_CONTAINER.contentEquals(commandApdu) && 
            !READ_CAPABILITY_CONTAINER_CHECK) {
            Log.i(TAG, "READ_CAPABILITY_CONTAINER triggered")
            READ_CAPABILITY_CONTAINER_CHECK = true
            return READ_CAPABILITY_CONTAINER_RESPONSE
        }
        
        // SELECT NDEF File
        if (NDEF_SELECT_OK.contentEquals(commandApdu)) {
            Log.i(TAG, "NDEF_SELECT_OK triggered")
            return A_OKAY
        }
        
        // READ BINARY NLEN (first 2 bytes)
        if (NDEF_READ_BINARY_NLEN.contentEquals(commandApdu)) {
            val response = ByteArray(2 + A_OKAY.size)
            val ndefBytes = ndefPayload ?: byteArrayOf()
            
            // NLEN = length of NDEF message
            val nlen = ndefBytes.size
            response[0] = (nlen shr 8).toByte()
            response[1] = nlen.toByte()
            System.arraycopy(A_OKAY, 0, response, 2, A_OKAY.size)
            
            Log.i(TAG, "NDEF_READ_BINARY_NLEN triggered, NLEN=$nlen")
            READ_CAPABILITY_CONTAINER_CHECK = false
            return response
        }
        
        // READ BINARY (NDEF Message)
        if (commandApdu.size >= 4 && 
            NDEF_READ_BINARY.contentEquals(commandApdu.sliceArray(0..1))) {
            val offset = (commandApdu[2].toInt() shl 8) or commandApdu[3].toInt()
            val length = if (commandApdu.size >= 5) commandApdu[4].toInt() else (ndefPayload?.size ?: 0) - offset
            
            val ndefBytes = ndefPayload ?: byteArrayOf()
            val realLength = if (offset + length <= ndefBytes.size) length else ndefBytes.size - offset
            
            if (realLength < 0) return A_ERROR
            
            val response = ByteArray(realLength + A_OKAY.size)
            System.arraycopy(ndefBytes, offset, response, 0, realLength)
            System.arraycopy(A_OKAY, 0, response, realLength, A_OKAY.size)
            
            Log.i(TAG, "NDEF_READ_BINARY triggered, offset=$offset, len=$realLength")
            return response
        }
        
        Log.w(TAG, "Unknown APDU: ${commandApdu.toHex()}")
        return A_ERROR
    }
    
    override fun onDeactivated(reason: Int) {
        Log.i(TAG, "onDeactivated() fired! Reason: $reason")
    }
    
    // Helper to convert byte array to hex string
    private fun ByteArray.toHex(): String {
        val result = StringBuffer()
        forEach {
            val octet = it.toInt()
            val firstIndex = (octet and 0xF0) ushr 4
            val secondIndex = octet and 0x0F
            result.append("0123456789ABCDEF"[firstIndex])
            result.append("0123456789ABCDEF"[secondIndex])
        }
        return result.toString()
    }
}
