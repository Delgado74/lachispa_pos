import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
import 'package:ndef_record/ndef_record.dart';
// import 'package:flutter_nfc_hce/flutter_nfc_hce.dart'; // Replaced with custom ElCaju-style implementation
import 'nfc_hce_service.dart'; // Our custom HCE service (like ElCaju)
import '../core/utils/proxy_config.dart';
import 'app_info_service.dart';
import '../l10n/generated/app_localizations.dart';

void _debugLog(String message) {
  if (kDebugMode) {
    print('[HCE_WALLET] $message');
  }
}

enum NfcChargeStatus {
  scanning,
  reading,
  charging,
  success,
  invalidTag,
  networkError,
  callbackError,
}

enum ModoNfcRecibir {
  hceWallet,    // Emitir HCE → pagador usa Phoenix u otra wallet
  lectorBoltcard, // Lector NFC   → pagador usa BoltCard física
}

class NfcChargeResult {
  final NfcChargeStatus status;
  final String? message;
  const NfcChargeResult(this.status, {this.message});
}

class NfcChargeService {
  final Dio _dio = Dio();
  bool _sessionActive = false;
  bool _processingTag = false;
  // ignore: unused_field
  final AppLocalizations _l10n;

  NfcChargeService(this._l10n) {
    _configureDio();
  }

  void _configureDio() {
    final isAndroid = !kIsWeb && Platform.isAndroid;
    _dio.options.headers['User-Agent'] = isAndroid
        ? AppInfoService.getUserAgent('Android')
        : AppInfoService.getUserAgent();
    _dio.options.headers['Accept'] = 'application/json';
    _dio.options.connectTimeout = const Duration(seconds: 15);
    _dio.options.receiveTimeout = const Duration(seconds: 15);
    _dio.options.sendTimeout = const Duration(seconds: 15);
    _dio.options.followRedirects = true;
    _dio.options.maxRedirects = 5;
    _dio.options.validateStatus =
        (status) => status != null && status >= 200 && status < 400;
    ProxyConfig.configureProxy(_dio);
  }

  static Future<bool> isAvailable() async {
    try {
      return await NfcManager.instance.isAvailable();
    } catch (e) {
      _debugLog('isAvailable threw: $e');
      return false;
    }
  }

  bool get isSessionActive => _sessionActive;

  Future<void> startChargeSession({
    required String lnurlOrInvoice,
    required ModoNfcRecibir modo,
    required void Function(NfcChargeResult) onStatus,
  }) async {
    if (_sessionActive) return;
    _sessionActive = true;

    // CRÍTICO: asegurarse que HCE está detenido antes de activar lector
    if (modo == ModoNfcRecibir.lectorBoltcard) {
      try { await NfcHceService.stopEmulating(); } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 300));
    }

    onStatus(const NfcChargeResult(NfcChargeStatus.scanning));

    try {
      switch (modo) {
        case ModoNfcRecibir.hceWallet:
          // HCE Mode: Emitir para wallet (Phoenix)
          _debugLog('Emitiendo para wallet: $lnurlOrInvoice');
          final isInvoice = lnurlOrInvoice.startsWith('lightning:lnbc') || lnurlOrInvoice.startsWith('lnbc');
          _debugLog('Tipo de contenido: ${isInvoice ? 'INVOICE' : 'LNURL'}');
          _debugLog('Longitud del contenido: ${lnurlOrInvoice.length}');
          if (isInvoice) {
            _debugLog('INVOICE detectada - primeros 30 chars: ${lnurlOrInvoice.substring(0, lnurlOrInvoice.length > 30 ? 30 : lnurlOrInvoice.length)}');
          }

          // CRÍTICO: Detener NfcManager y HCE previo antes de iniciar HCE
          try {
            await NfcManager.instance.stopSession();
            _debugLog('NfcManager detenido correctamente');
          } catch (_) {}
          try {
            await NfcHceService.stopEmulating();
            _debugLog('HCE previo detenido');
          } catch (_) {}
          await Future.delayed(const Duration(milliseconds: 500));

          // Verificar contenido no vacío
          if (lnurlOrInvoice.isEmpty) {
            _debugLog('ERROR: Contenido vacío');
            onStatus(const NfcChargeResult(NfcChargeStatus.invalidTag));
            break;
          }

          await NfcHceService.startEmulating(lnurlOrInvoice);
          _debugLog('Emulación NFC iniciada correctamente');
          onStatus(const NfcChargeResult(NfcChargeStatus.reading));
          // HCE queda activo esperando que un lector se conecte
          // El usuario debe detener la sesión manualmente
          break;

        case ModoNfcRecibir.lectorBoltcard:
          // BoltCard Mode: Lector NFC
          _debugLog('NFC: Iniciando lectura de tarjeta');
          await NfcManager.instance.startSession(
            pollingOptions: {NfcPollingOption.iso14443},
            onDiscovered: (NfcTag tag) async {
              if (_processingTag) return;
              _processingTag = true;
              try {
                onStatus(const NfcChargeResult(NfcChargeStatus.reading));

                final url = _extractUriFromTag(tag);
                if (url == null) {
                  onStatus(const NfcChargeResult(NfcChargeStatus.invalidTag));
                  await _safeStop();
                  return;
                }
                _debugLog('Tag URL: $url');

                final metaResponse = await _dio.get(url);
                final meta = metaResponse.data;
                if (meta is! Map) {
                  onStatus(const NfcChargeResult(NfcChargeStatus.invalidTag));
                  await _safeStop();
                  return;
                }
                if (meta['tag'] != 'withdrawRequest') {
                  onStatus(const NfcChargeResult(NfcChargeStatus.invalidTag));
                  await _safeStop();
                  return;
                }
                final callbackValue = meta['callback'];
                final k1Value = meta['k1'];
                if (callbackValue is! String ||
                    callbackValue.isEmpty ||
                    k1Value is! String ||
                    k1Value.isEmpty) {
                  onStatus(const NfcChargeResult(NfcChargeStatus.invalidTag));
                  await _safeStop();
                  return;
                }
                final callback = callbackValue;
                final k1 = k1Value;

                onStatus(const NfcChargeResult(NfcChargeStatus.charging));

                final claim = await _dio.get(callback, queryParameters: {
                  'k1': k1,
                  'pr': lnurlOrInvoice,
                });

                final claimData = claim.data;
                if (claimData is Map && claimData['status'] == 'OK') {
                  onStatus(const NfcChargeResult(NfcChargeStatus.success));
                  await _safeStop();
                } else {
                  final reason = claimData is Map
                      ? claimData['reason']?.toString()
                      : null;
                  onStatus(NfcChargeResult(
                    NfcChargeStatus.callbackError,
                    message: reason,
                  ));
                  await _safeStop();
                }
                } catch (e) {
                _debugLog('Discovery handler error: $e');
                onStatus(NfcChargeResult(
                  NfcChargeStatus.networkError,
                  message: e.toString(),
                ));
                await _safeStop();
              } finally {
                _processingTag = false;
                _sessionActive = false;
              }
            },
          );
          break;
      }
    } catch (e) {
      _debugLog('startSession error: $e');
      _sessionActive = false;
      onStatus(NfcChargeResult(
        NfcChargeStatus.networkError,
        message: e.toString(),
      ));
    }
  }

  Future<void> stopSession() async {
    await _safeStop();
    try { await NfcHceService.stopEmulating(); } catch (_) {}
    _sessionActive = false;
    _processingTag = false;
  }

  Future<void> _safeStop() async {
    try {
      await NfcManager.instance.stopSession();
    } catch (_) {
      // ignore
    }
  }

  String? _extractUriFromTag(NfcTag tag) {
    final ndef = NdefAndroid.from(tag);
    if (ndef == null) {
      _debugLog('Ndef es null - la tarjeta no soporta NDEF');
      return null;
    }
    final message = ndef.cachedNdefMessage;
    if (message == null || message.records.isEmpty) {
      _debugLog('No hay registros NDEF');
      return null;
    }

    for (final record in message.records) {
      String? raw;

      if (record.typeNameFormat == TypeNameFormat.wellKnown &&
          record.type.length == 1 &&
          record.type[0] == 0x55 &&
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
      } else {
        if (record.payload.isNotEmpty) {
          raw = utf8.decode(record.payload, allowMalformed: true).trim();
        }
      }

      if (raw != null) {
        _debugLog('URI extraída: $raw');
        // Normalize common LNURL-W prefixes
        String normalized = raw;
        if (normalized.toLowerCase().startsWith('lnurlw://')) {
          normalized = 'https://${normalized.substring(9)}';
        } else if (normalized.toLowerCase().startsWith('lnurlw:')) {
          normalized = 'https://${normalized.substring(8)}';
        }
        return normalized;
      }
    }
    return null;
  }

  void dispose() {
    stopSession();
    _dio.close(force: true);
  }
}
