import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/services.dart';

/// Wake Word Service - gerencia a escuta contínua em segundo plano.
///
/// ## Android:
/// - Usa um ForegroundService nativo (Kotlin) que roda com notificação persistente
/// - O serviço escuta "Ei Bruno" via SpeechRecognizer nativo do Android
/// - Quando detecta o wake word, abre o app automaticamente com o comando
///
/// ## iOS:
/// - iOS NÃO permite apps de terceiros escutarem continuamente em background
/// - A única alternativa é usar Siri Shortcuts
/// - Este serviço retorna false e informa a limitação
class WakeService {
  static const MethodChannel _channel =
      MethodChannel('voz_comando/phone_control');

  static final WakeService _instance = WakeService._internal();
  factory WakeService() => _instance;
  WakeService._internal();

  bool _isRunning = false;
  bool get isRunning => _isRunning;

  /// Inicia o modo wake word em background.
  /// Retorna true se iniciou com sucesso.
  Future<bool> start() async {
    if (!Platform.isAndroid) {
      developer.log(
          'WakeService: iOS não suporta background listening nativo.');
      return false;
    }
    try {
      final result =
          await _channel.invokeMethod<bool>('startWakeService') ?? false;
      _isRunning = result;
      developer.log('WakeService: iniciado = $result');
      return result;
    } catch (e) {
      developer.log('WakeService erro ao iniciar: $e');
      return false;
    }
  }

  /// Para o modo wake word.
  Future<void> stop() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('stopWakeService');
      _isRunning = false;
      developer.log('WakeService: parado');
    } catch (e) {
      developer.log('WakeService erro ao parar: $e');
    }
  }

  void dispose() {}
}
