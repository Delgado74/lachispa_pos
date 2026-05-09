import 'package:flutter/services.dart';

/// Servicio HCE para emulación de etiquetas NFC.
/// Emite URI Records (tipo 'U') con prefijo lightning: para que
/// las wallets Lightning procesen el pago automáticamente.
class NfcHceService {
  static const _channel = MethodChannel('lachispa/nfc_hce');

  /// Inicia emulación HCE con el contenido Lightning (LNURL, BOLT11, etc.)
  static Future<void> startEmulating(String content) async {
    final String normalized;
    final lower = content.trim().toLowerCase();
    if (lower.startsWith('lightning:')) {
      normalized = content.trim();
    } else {
      normalized = 'lightning:${content.trim()}';
    }
    final ndefMessage = _buildNdefUriRecord(normalized);
    await _channel.invokeMethod('setPayload', {'payload': ndefMessage});
  }

  /// Detiene la emulación HCE.
  static Future<void> stopEmulating() async {
    await _channel.invokeMethod('clearPayload');
  }

  /// Construye un NDEF URI Record (TNF well-known, tipo 'U' = 0x55).
  /// Maneja registros cortos (≤255 bytes) y largos (>255 bytes).
  static Uint8List _buildNdefUriRecord(String uri) {
    final uriBytes = Uint8List.fromList(uri.codeUnits);

    // Payload URI: [prefix_byte=0x00][uri_bytes]
    // 0x00 = sin abreviación (lightning: no está en tabla NFC Forum)
    final payload = Uint8List(1 + uriBytes.length);
    payload[0] = 0x00;
    payload.setRange(1, payload.length, uriBytes);

    final payloadLen = payload.length;

    if (payloadLen <= 255) {
      // Short Record
      final record = Uint8List(4 + payloadLen);
      record[0] = 0xD1; // MB | ME | SR | TNF=well-known
      record[1] = 0x01; // Type Length = 1
      record[2] = payloadLen;
      record[3] = 0x55; // 'U' = URI Record
      record.setRange(4, record.length, payload);
      return record;
    } else {
      // Long Record (bolt11 puede superar 255 bytes)
      final record = Uint8List(7 + payloadLen);
      record[0] = 0xC1; // MB | ME | TNF=well-known (sin SR)
      record[1] = 0x01;
      record[2] = (payloadLen >> 24) & 0xFF;
      record[3] = (payloadLen >> 16) & 0xFF;
      record[4] = (payloadLen >> 8) & 0xFF;
      record[5] = payloadLen & 0xFF;
      record[6] = 0x55; // 'U' = URI Record
      record.setRange(7, record.length, payload);
      return record;
    }
  }
}
