import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';  // Para Uint8List
import 'package:nfc_manager/nfc_manager.dart';
// Importar IsoDepAndroid para Android (como ElCaju)
import 'package:nfc_manager/nfc_manager_android.dart';
import 'package:ndef_record/ndef_record.dart';

void _debugLog(String message) {
  if (identical(Zone.current, Zone.root)) {
    print('[NFC_READ] $message');
  }
}

enum NfcReadResultType {
  lightningAddress,
  lnurl,
  bolt11,
  unknown,
}

class NfcReadResult {
  final NfcReadResultType type;
  final String value;
  const NfcReadResult(this.type, this.value);
}

class NfcReadService {
  bool _sessionActive = false;

  static Future<bool> isAvailable() async {
    try {
      // Using isAvailable - may show deprecation warning but works reliably
      // ignore: deprecated_member_use
      return await NfcManager.instance.isAvailable();
    } catch (e) {
      _debugLog('isAvailable error: $e');
      return false;
    }
  }

  Future<void> startReadSession({
    required void Function(NfcReadResult) onResult,
    required void Function(String) onError,
  }) async {
    if (_sessionActive) return;
    _sessionActive = true;

    try {
      await NfcManager.instance.startSession(
        pollingOptions: {NfcPollingOption.iso14443},
        onDiscovered: (NfcTag tag) async {
          try {
            final result = await _extractDataFromTag(tag);
            if (result != null) {
              onResult(result);
            } else {
              onError('Tag no contiene una dirección válida');
            }
          } catch (e) {
            _debugLog('Read error: $e');
            onError(e.toString());
          } finally {
            _sessionActive = false;
          }
        },
      );
    } catch (e) {
      _debugLog('startSession error: $e');
      _sessionActive = false;
      onError(e.toString());
    }
  }

  Future<void> stopSession() async {
    try {
      await NfcManager.instance.stopSession();
    } catch (_) {
      // ignore
    }
    _sessionActive = false;
  }

   Future<NfcReadResult?> _extractDataFromTag(NfcTag tag) async {
    // 1. INTENTAR ISODEP PRIMERO (HCE phone-to-phone - como ElCaju)
    final isoDep = IsoDepAndroid.from(tag);
    if (isoDep != null) {
      _debugLog('Tag is IsoDep (HCE) - leyendo via APDU');
      final result = await _readViaIsoDep(isoDep);
      if (result != null) return result;
      _debugLog('IsoDep falló, probando NDEF...');
    }

    // 2. FALLBACK A NDEF (etiquetas físicas)
    final ndef = NdefAndroid.from(tag);
    if (ndef == null) {
      _debugLog('Ndef es null');
      return null;
    }
    final message = ndef.cachedNdefMessage;
    if (message == null || message.records.isEmpty) {
      _debugLog('No hay registros NDEF');
      return null;
    }

    for (final record in message.records) {
      String? raw;


      // Handle URI records (NFC Well-known type for URIs)
      if (record.typeNameFormat == TypeNameFormat.wellKnown &&
          record.type.length == 1 &&
          record.type[0] == 0x55 &&  // 'U' for URI
          record.payload.isNotEmpty) {
        // URI prefix list (standard NFC Forum)
        const uriPrefixes = [
          '', // 0x00
          'http://www.', // 0x01
          'https://www.', // 0x02
          'http://', // 0x03
          'https://', // 0x04
          'tel:', // 0x05
          'mailto:', // 0x06
          'ftp://anonymous:anonymous@', // 0x07
          'ftp://ftp.', // 0x08
          'ftps://', // 0x09
          'sftp://', // 0x0A
          'smb://', // 0x0B
          'nfs://', // 0x0C
          'ftp://', // 0x0D
          'dav://', // 0x0E
          'news:', // 0x0F
          'telnet://', // 0x10
          'imap:', // 0x11
          'rtsp://', // 0x12
          'urn:', // 0x13
          'pop:', // 0x14
          'sip:', // 0x15
          'sips:', // 0x16
          'tftp:', // 0x17
          'btspp://', // 0x18
          'btl2cap://', // 0x19
          'btgoep://', // 0x1A
          'tcpobex://', // 0x1B
          'irdaobex://', // 0x1C
          'irdavcal://', // 0x1D
          'irc://', // 0x1E
          'mailto:', // 0x1F
        ];
        final prefixIndex = record.payload[0];
        final prefix = (prefixIndex < uriPrefixes.length) ? uriPrefixes[prefixIndex] : '';
        final urlBytes = record.payload.sublist(1);
        raw = prefix + utf8.decode(urlBytes, allowMalformed: true);
        _debugLog('URI record leído: $raw');
      }
      // Handle RTD_TEXT records (plain text with language code)
      else if (record.typeNameFormat == TypeNameFormat.wellKnown &&
          record.type.length == 1 &&
          record.type[0] == 0x54 &&  // 'T' for Text
          record.payload.length > 1) {
        final statusByte = record.payload[0];
        final encoding = ((statusByte & 0x80) == 0 ? utf8 : Encoding.getByName('utf-16')) ?? utf8;
        final langLength = statusByte & 0x3F;
        if (record.payload.length > 1 + langLength) {
          final contentBytes = record.payload.sublist(1 + langLength);
          raw = encoding.decode(contentBytes).trim();
          _debugLog('RTD_TEXT decodificado: $raw');
        }
      }
      // Handle Media records (MIME types like text/plain)
      else if (record.typeNameFormat == TypeNameFormat.media) {
        final payload = record.payload;
        if (payload.isNotEmpty) {
          raw = utf8.decode(payload, allowMalformed: true).trim();
          _debugLog('Media record leído: $raw');
        }
      }
      // Fallback for other record types
      else {
        final payload = record.payload;
        if (payload.isNotEmpty) {
          if (payload.length > 1) {
            final statusByte = payload[0];
            final encoding = ((statusByte & 0x80) == 0 ? utf8 : Encoding.getByName('utf-16')) ?? utf8;
            final langLength = statusByte & 0x3F;
            if (payload.length > 1 + langLength) {
              final contentBytes = payload.sublist(1 + langLength);
              raw = encoding.decode(contentBytes).trim();
            } else {
              raw = utf8.decode(payload, allowMalformed: true).trim();
            }
          } else {
            raw = utf8.decode(payload, allowMalformed: true).trim();
          }
          _debugLog('Fallback decodificado: $raw');
        }
      }

      if (raw != null) {
        _debugLog('Dato leído: $raw');
        final result = _classifyData(raw);
        if (result != null) return result;
      }
    }
    return null;
  }

  NfcReadResult? _classifyData(String raw) {
    String original = raw.trim();
    String lower = original.toLowerCase();

    // Remove lightning: prefix for processing
    String processed = original;
    if (lower.startsWith('lightning:')) {
      processed = original.substring(10);
      lower = processed.toLowerCase();
    }

    // Check for BOLT11 invoice (lnbc, lntb, lnbcrt)
    if (lower.startsWith('lnbc') ||
        lower.startsWith('lntb') ||
        lower.startsWith('lnbcrt')) {
      return NfcReadResult(NfcReadResultType.bolt11, processed);
    }

    // Check for LNURL (bech32)
    if (lower.startsWith('lnurl1')) {
      return NfcReadResult(NfcReadResultType.lnurl, processed);
    }

    // Check for LNURLP URI
    if (lower.startsWith('lnurlp://') || lower.startsWith('lnurlp:')) {
      return NfcReadResult(NfcReadResultType.lnurl, processed);
    }

    // Check for Lightning Address
    if (processed.contains('@') && processed.split('@').length == 2) {
      final parts = processed.split('@');
      if (parts[0].isNotEmpty && parts[1].contains('.')) {
        return NfcReadResult(NfcReadResultType.lightningAddress, processed);
      }
    }

    // Check for HTTP/HTTPS URLs
    if (lower.startsWith('https://') || lower.startsWith('http://')) {
      return NfcReadResult(NfcReadResultType.lnurl, processed);
    }

    return null;
  }

  // ─── IsoDep Reading (copiado de ElCaju) ───

  /// Read NDEF from HCE via IsoDep APDU commands (like ElCaju).
  /// Bypasses manufacturer NFC services (Xiaomi, Samsung, etc).
  /// Returns NfcReadResult if successful.
  Future<NfcReadResult?> _readViaIsoDep(IsoDepAndroid isoDep) async {
    try {
      // Helper para verificar respuesta APDU OK (90 00)
      bool isOk(Uint8List response) {
        return response.length >= 2 &&
               response[response.length - 2] == 0x90 &&
               response[response.length - 1] == 0x00;
      }

       // 1. SELECT NDEF Application estándar (D2760000850101)
      var response = await isoDep.transceive(Uint8List.fromList([
        0x00, 0xA4, 0x04, 0x00, 0x07,
        0xD2, 0x76, 0x00, 0x00, 0x85, 0x01, 0x01,
        0x00,
      ]));
      if (!isOk(response)) {
        _debugLog('IsoDep: SELECT NDEF App falló — no es HCE compatible');
        return null;
      }

      // 3. SELECT CC File (E103)
      response = await isoDep.transceive(Uint8List.fromList([
        0x00, 0xA4, 0x00, 0x0C, 0x02,
        0xE1, 0x03,
      ]));
      if (!isOk(response)) {
        _debugLog('IsoDep: SELECT CC falló');
        return null;
      }

      // 4. READ_BINARY (CC)
      response = await isoDep.transceive(Uint8List.fromList([
        0x00, 0xB0, 0x00, 0x00, 0x0F,
      ]));

      // 5. SELECT NDEF File (E104)
      response = await isoDep.transceive(Uint8List.fromList([
        0x00, 0xA4, 0x00, 0x0C, 0x02,
        0xE1, 0x04,
      ]));
      if (!isOk(response)) {
        _debugLog('IsoDep: SELECT NDEF File falló');
        return null;
      }

      // 6. READ_BINARY (NLEN primero - 2 bytes)
      response = await isoDep.transceive(Uint8List.fromList([
        0x00, 0xB0, 0x00, 0x00, 0x02,
      ]));
      if (response.length < 4 || !isOk(response)) {
        _debugLog('IsoDep: READ NLEN falló');
        return null;
      }

      final ndefLen = (response[0] << 8) | response[1];
      if (ndefLen == 0) {
        _debugLog('IsoDep: NDEF vacío (NLEN=0)');
        return null;
      }

      // 7. READ NDEF Message en chunks (máximo 255 bytes por lectura)
      final ndefBytes = <int>[];
      var offset = 2; // Saltar NLEN
      var remaining = ndefLen;

      while (remaining > 0) {
        final chunkSize = remaining > 255 ? 255 : remaining;
        response = await isoDep.transceive(Uint8List.fromList([
          0x00, 0xB0,
          (offset >> 8) & 0xFF, offset & 0xFF,
          chunkSize,
        ]));

        if (response.length <= 2 || !isOk(response)) break;

        // Remover SW1 SW2 (últimos 2 bytes)
        ndefBytes.addAll(response.sublist(0, response.length - 2));
        offset += (response.length - 2);
        remaining -= (response.length - 2);
      }

      // 8. Parsear NDEF bytes y extraer texto
      final raw = Uint8List.fromList(ndefBytes);
      if (raw.isEmpty) return null;

      _debugLog('IsoDep: NDEF leído (${raw.length} bytes)');
      final text = _extractTextFromNdefBytes(raw);
      if (text != null) {
        _debugLog('IsoDep: Texto extraído: $text');
        return _classifyData(text);
      }

      return null;
    } catch (e) {
      _debugLog('IsoDep error: $e');
      return null;
    }
  }

  /// Parsear bytes NDEF y extraer texto (copiado de ElCaju).
  /// Maneja Text Records (0x54) y URI Records (0x55).
  String? _extractTextFromNdefBytes(List<int> raw) {
    if (raw.isEmpty) return null;

    var pos = 0;
    while (pos < raw.length) {
      if (pos + 3 > raw.length) break;

      final flags = raw[pos++];
      final tnf = flags & 0x07;
      final isShortRecord = (flags & 0x10) != 0;
      final hasIdLength = (flags & 0x08) != 0;

      // Type length
      if (pos >= raw.length) break;
      final typeLength = raw[pos++];

      // Payload length
      int payloadLength;
      if (isShortRecord) {
        if (pos >= raw.length) break;
        payloadLength = raw[pos++];
      } else {
        if (pos + 3 >= raw.length) break;
        payloadLength = (raw[pos] << 24) |
            (raw[pos + 1] << 16) |
            (raw[pos + 2] << 8) |
            raw[pos + 3];
        pos += 4;
      }

      // Skip ID if present
      if (hasIdLength) {
        if (pos >= raw.length) break;
        final idLen = raw[pos++];
        pos += idLen;
      }

      // Type
      if (pos + typeLength > raw.length) break;
      final type = raw.sublist(pos, pos + typeLength);
      pos += typeLength;

      // Payload
      if (pos + payloadLength > raw.length) break;
      final payload = raw.sublist(pos, pos + payloadLength);
      pos += payloadLength;

      // Check: Text Record (TNF=0x01, type='T' = 0x54)
      if (tnf == 0x01 && typeLength == 1 && type[0] == 0x54) {
        if (payload.isNotEmpty) {
          final langLen = payload[0] & 0x3F;
          if (payload.length > 1 + langLen) {
            final text = String.fromCharCodes(payload.sublist(1 + langLen));
            return text;
          }
        }
      }

      // Check: URI Record (TNF=0x01, type='U' = 0x55)
      if (tnf == 0x01 && typeLength == 1 && type[0] == 0x55) {
        if (payload.isNotEmpty) {
          const prefixes = [
            '', // 0x00
            'http://www.', // 0x01
            'https://www.', // 0x02
            'http://', // 0x03
            'https://', // 0x04
            'tel:', // 0x05
            'mailto:', // 0x06
            'ftp://anonymous:anonymous@', // 0x07
            'ftp://ftp.', // 0x08
            'ftps://', // 0x09
            'sftp://', // 0x0A
            'smb://', // 0x0B
            'nfs://', // 0x0C
            'ftp://', // 0x0D
            'dav://', // 0x0E
            'news:', // 0x0F
            'telnet://', // 0x10
            'imap:', // 0x11
            'rtsp://', // 0x12
            'urn:', // 0x13
            'pop:', // 0x14
            'sip:', // 0x15
            'sips:', // 0x16
            'tftp:', // 0x17
            'btspp://', // 0x18
            'btl2cap://', // 0x19
            'btgoep://', // 0x1A
            'tcpobex://', // 0x1B
            'irdaobex://', // 0x1C
            'irdavcal://', // 0x1D
            'irc://', // 0x1E
            'mailto:', // 0x1F
          ];
          final prefixIdx = payload[0];
          final prefix =
              prefixIdx < prefixes.length ? prefixes[prefixIdx] : '';
          final rest =
              String.fromCharCodes(payload.sublist(1));
          return '$prefix$rest';
        }
      }

      // Si ME (Message End) flag está set, parar
      if ((flags & 0x40) != 0) break;
    }
    return null;
  }

  void dispose() {
    stopSession();
  }
}
