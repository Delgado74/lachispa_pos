import 'dart:async';
import 'dart:convert';
import 'package:nfc_manager/nfc_manager.dart';

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
        pollingOptions: NfcPollingOption.values.toSet(),
        invalidateAfterFirstRead: true,
        alertMessage: 'Acerca la tarjeta',
        onDiscovered: (NfcTag tag) async {
          try {
            final result = _extractDataFromTag(tag);
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

  NfcReadResult? _extractDataFromTag(NfcTag tag) {
    final ndef = Ndef.from(tag);
    if (ndef == null) {
      _debugLog('Ndef es null');
      return null;
    }
    final message = ndef.cachedMessage;
    if (message == null || message.records.isEmpty) {
      _debugLog('No hay registros NDEF');
      return null;
    }

    for (final record in message.records) {
      String? raw;

      // Handle URI records (NFC Well-known type for URIs)
      if (record.typeNameFormat == NdefTypeNameFormat.nfcWellknown &&
          record.type.length == 1 &&
          record.type[0] == 0x55 &&  // 'U' for URI
          record.payload.isNotEmpty) {
        final prefixIndex = record.payload[0];
        final prefix = (prefixIndex < NdefRecord.URI_PREFIX_LIST.length)
            ? NdefRecord.URI_PREFIX_LIST[prefixIndex]
            : '';
        final urlBytes = record.payload.sublist(1);
        raw = prefix + utf8.decode(urlBytes, allowMalformed: true);
        _debugLog('URI record leído: $raw');
      }
      // Handle RTD_TEXT records (plain text with language code)
      else if (record.typeNameFormat == NdefTypeNameFormat.nfcWellknown &&
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
      else if (record.typeNameFormat == NdefTypeNameFormat.media) {
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

  void dispose() {
    stopSession();
  }
}
