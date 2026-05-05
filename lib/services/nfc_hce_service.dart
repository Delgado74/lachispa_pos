import 'dart:typed_data';
import 'package:flutter/services.dart';

/// Servicio HCE para emulación de etiquetas NFC.
/// Basado en la implementación de ElCaju que SÍ funciona.
/// Construye NDEF en Dart y lo envía vía MethodChannel.
class NfcHceService {
  static const _channel = MethodChannel('lachispa/nfc_hce');

  /// Inicia emulación HCE con el texto proporcionado (LNURL, BOLT11, etc.)
  static Future<void> startEmulating(String text) async {
    final ndefMessage = _buildNdefTextMessage(text);
    await _channel.invokeMethod('setPayload', {'payload': ndefMessage});
  }

  /// Detiene la emulación HCE.
  static Future<void> stopEmulating() async {
    await _channel.invokeMethod('clearPayload');
  }

  /// Construye un mensaje NDEF con registro de texto.
  /// Maneja tanto registros cortos (≤255 bytes) como largos (>255 bytes).
  /// Compatible con ElCaju y estándar NFC Forum Type 4.
  static Uint8List _buildNdefTextMessage(String text) {
    final textBytes = Uint8List.fromList(text.codeUnits);
    final languageCode = Uint8List.fromList('en'.codeUnits);

    // NDEF Text Record payload: [status byte][lang code][text]
    final recordPayload = Uint8List(1 + languageCode.length + textBytes.length);
    recordPayload[0] = languageCode.length;
    recordPayload.setRange(1, 1 + languageCode.length, languageCode);
    recordPayload.setRange(1 + languageCode.length, recordPayload.length, textBytes);

    final payloadLength = recordPayload.length;
    final isShortRecord = payloadLength <= 255;

    if (isShortRecord) {
      // Short Record: flags(1) + typeLen(1) + payloadLen(1) + type(1) + payload
      final record = Uint8List(4 + payloadLength);
      record[0] = 0xD1; // MB|ME|SR|TNF=well-known
      record[1] = 1;    // type length
      record[2] = payloadLength;
      record[3] = 0x54; // 'T' for Text
      record.setRange(4, 4 + payloadLength, recordPayload);
      return record;
    } else {
      // Long Record: flags(1) + typeLen(1) + payloadLen(4) + type(1) + payload
      final record = Uint8List(7 + payloadLength);
      record[0] = 0xC1; // MB|ME|TNF=well-known (no SR flag)
      record[1] = 1;    // type length
      record[2] = (payloadLength >> 24) & 0xFF;
      record[3] = (payloadLength >> 16) & 0xFF;
      record[4] = (payloadLength >> 8) & 0xFF;
      record[5] = payloadLength & 0xFF;
      record[6] = 0x54; // 'T'
      record.setRange(7, 7 + payloadLength, recordPayload);
      return record;
    }
  }
}
