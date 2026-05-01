import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:nfc_manager/nfc_manager.dart';
import '../core/utils/proxy_config.dart';
import 'app_info_service.dart';

void _debugLog(String message) {
  if (kDebugMode) {
    print('[NFC_CHARGE] $message');
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

class NfcChargeResult {
  final NfcChargeStatus status;
  final String? message;
  const NfcChargeResult(this.status, {this.message});
}

class NfcChargeService {
  final Dio _dio = Dio();
  bool _sessionActive = false;

  NfcChargeService() {
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
    required String invoice,
    required void Function(NfcChargeResult) onStatus,
  }) async {
    if (_sessionActive) return;
    _sessionActive = true;
    onStatus(const NfcChargeResult(NfcChargeStatus.scanning));

    try {
      await NfcManager.instance.startSession(
        pollingOptions: NfcPollingOption.values.toSet(),
        invalidateAfterFirstRead: true,
        alertMessage: 'Acerca la tarjeta',
        onDiscovered: (NfcTag tag) async {
          try {
            onStatus(const NfcChargeResult(NfcChargeStatus.reading));

            final url = _extractUriFromTag(tag);
            if (url == null) {
              onStatus(const NfcChargeResult(NfcChargeStatus.invalidTag));
              await _safeStop(errorMessage: 'Tag no compatible');
              return;
            }
            _debugLog('Tag URL: $url');

            final metaResponse = await _dio.get(url);
            final meta = metaResponse.data;
            if (meta is! Map) {
              onStatus(const NfcChargeResult(NfcChargeStatus.invalidTag));
              await _safeStop(errorMessage: 'Respuesta inválida');
              return;
            }
            if (meta['tag'] != 'withdrawRequest') {
              onStatus(const NfcChargeResult(NfcChargeStatus.invalidTag));
              await _safeStop(errorMessage: 'No es Boltcard');
              return;
            }
            final callbackValue = meta['callback'];
            final k1Value = meta['k1'];
            if (callbackValue is! String ||
                callbackValue.isEmpty ||
                k1Value is! String ||
                k1Value.isEmpty) {
              onStatus(const NfcChargeResult(NfcChargeStatus.invalidTag));
              await _safeStop(errorMessage: 'Datos incompletos');
              return;
            }
            final callback = callbackValue;
            final k1 = k1Value;

            onStatus(const NfcChargeResult(NfcChargeStatus.charging));

            final claim = await _dio.get(callback, queryParameters: {
              'k1': k1,
              'pr': invoice,
            });

            final claimData = claim.data;
            if (claimData is Map && claimData['status'] == 'OK') {
              onStatus(const NfcChargeResult(NfcChargeStatus.success));
              await _safeStop(alertMessage: 'OK');
            } else {
              final reason = claimData is Map
                  ? claimData['reason']?.toString()
                  : null;
              onStatus(NfcChargeResult(
                NfcChargeStatus.callbackError,
                message: reason,
              ));
              await _safeStop(errorMessage: reason);
            }
          } catch (e) {
            _debugLog('Discovery handler error: $e');
            onStatus(NfcChargeResult(
              NfcChargeStatus.networkError,
              message: e.toString(),
            ));
            await _safeStop(errorMessage: 'Error de red');
          } finally {
            _sessionActive = false;
          }
        },
      );
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
    _sessionActive = false;
  }

  Future<void> _safeStop({String? alertMessage, String? errorMessage}) async {
    try {
      await NfcManager.instance.stopSession(
        alertMessage: alertMessage,
        errorMessage: errorMessage,
      );
    } catch (_) {
      // ignore
    }
  }

  String? _extractUriFromTag(NfcTag tag) {
    final ndef = Ndef.from(tag);
    if (ndef == null) return null;
    final message = ndef.cachedMessage;
    if (message == null || message.records.isEmpty) return null;

    for (final record in message.records) {
      if (record.typeNameFormat == NdefTypeNameFormat.nfcWellknown &&
          record.type.length == 1 &&
          record.type[0] == 0x55 &&
          record.payload.isNotEmpty) {
        final prefixIndex = record.payload[0];
        final prefix = (prefixIndex < NdefRecord.URI_PREFIX_LIST.length)
            ? NdefRecord.URI_PREFIX_LIST[prefixIndex]
            : '';
        final urlBytes = record.payload.sublist(1);
        final raw = prefix + utf8.decode(urlBytes, allowMalformed: true);
        return _normalizeLnurlw(raw);
      }
    }
    return null;
  }

  String? _normalizeLnurlw(String raw) {
    if (raw.isEmpty) return null;
    if (raw.startsWith('lnurlw://')) {
      return 'https://${raw.substring(9)}';
    }
    if (raw.startsWith('lnurlw:')) {
      return 'https://${raw.substring(7)}';
    }
    if (raw.startsWith('https://') || raw.startsWith('http://')) {
      return raw;
    }
    return null;
  }

  void dispose() {
    _dio.close(force: true);
  }
}
