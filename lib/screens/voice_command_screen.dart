import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/intent.dart';
import '../services/action_executor.dart';
import '../services/app_resolver.dart';
import '../services/contacts_service.dart';
import '../services/intent_parser.dart';
import '../services/speech_service.dart';
import '../services/tts_service.dart';

enum VoiceUiState { aguardando, ouvindo, processando, executando, erro }

class VoiceCommandScreen extends StatefulWidget {
  const VoiceCommandScreen({super.key});

  @override
  State<VoiceCommandScreen> createState() => _VoiceCommandScreenState();
}

class _VoiceCommandScreenState extends State<VoiceCommandScreen> {
  final SpeechService _speechService = SpeechService();
  final TtsService _ttsService = TtsService();
  final IntentParser _intentParser = IntentParser();
  final ActionExecutor _executor = ActionExecutor(
    VoiceContactsService(),
    AppResolver(),
  );

  VoiceUiState _state = VoiceUiState.aguardando;
  String _recognizedText = 'Toque no microfone para começar';
  String _detectedAction = 'Nenhuma ação detectada';
  Timer? _processTimer;
  String _lastProcessedText = '';

  String _labelEstado() {
    switch (_state) {
      case VoiceUiState.aguardando:
        return 'Aguardando';
      case VoiceUiState.ouvindo:
        return 'Ouvindo';
      case VoiceUiState.processando:
        return 'Processando';
      case VoiceUiState.executando:
        return 'Executando';
      case VoiceUiState.erro:
        return 'Erro';
    }
  }

  Color _stateColor() {
    switch (_state) {
      case VoiceUiState.aguardando:
        return const Color(0xFF5C7CFF);
      case VoiceUiState.ouvindo:
        return const Color(0xFF2CCBFF);
      case VoiceUiState.processando:
        return const Color(0xFF835BFF);
      case VoiceUiState.executando:
        return const Color(0xFF20E3B2);
      case VoiceUiState.erro:
        return const Color(0xFFFF5C8A);
    }
  }

  String _promptText() {
    final text = _recognizedText.trim();
    if (text.isEmpty || text == 'Toque no microfone para começar') {
      return 'Diga: "Mapear celular"';
    }
    return text;
  }

  @override
  void initState() {
    super.initState();
    _setup();
  }

  Future<void> _setup() async {
    await _ttsService.initialize();
    await _requestPermissions();
    await _speechService.initialize();
  }

  Future<void> _requestPermissions() async {
    await Permission.microphone.request();
    await Permission.contacts.request();
  }

  Future<void> _onMicTap() async {
    if (_speechService.isListening) {
      await _speechService.stopListening();
      return;
    }

    setState(() => _state = VoiceUiState.ouvindo);
    await _speechService.startListening(
      onResult: (String text, bool isFinal) async {
        setState(() => _recognizedText = text.isEmpty ? '...' : text);
        if (text.trim().isEmpty) return;

        _processTimer?.cancel();
        if (isFinal) {
          await _processRecognizedText(text);
          return;
        }

        _processTimer = Timer(const Duration(milliseconds: 1200), () {
          _processRecognizedText(text);
        });
      },
    );
  }

  Future<void> _processRecognizedText(String text) async {
    final normalized = text.trim().toLowerCase();
    if (normalized.isEmpty || normalized == _lastProcessedText) return;

    _lastProcessedText = normalized;
    _processTimer?.cancel();
    await _speechService.stopListening();
    await _process(text);
  }

  Future<void> _process(String text) async {
    setState(() => _state = VoiceUiState.processando);
    final intent = await _intentParser.parse(text);
    setState(() => _detectedAction = _actionText(intent));

    if (!intent.isKnown) {
      setState(() => _state = VoiceUiState.erro);
      await _ttsService.speak('Não consegui entender, tente novamente.');
      return;
    }

    if (intent.ambiguous) {
      setState(() => _state = VoiceUiState.erro);
      await _ttsService.speak(
        intent.confirmationQuestion ?? 'Seu comando está ambíguo.',
      );
      return;
    }

    if ((intent.action == VoiceAction.ligarPara ||
            intent.action == VoiceAction.abrirWhatsappContato) &&
        intent.target != null) {
      final matches = await _executor.findContacts(intent.target!);
      if (matches.length > 1) {
        setState(() => _state = VoiceUiState.aguardando);
        final top = matches.take(2).map((m) => m.name).join(' e ');
        await _ttsService.speak('Encontrei $top, qual você quer?');
        return;
      }
    }

    final canRun = await _confirmExecution(intent);
    if (!canRun) {
      setState(() => _state = VoiceUiState.aguardando);
      return;
    }

    setState(() => _state = VoiceUiState.executando);
    final result = await _executor.execute(intent);
    await _ttsService.speak(result.message);

    setState(
      () =>
          _state = result.success ? VoiceUiState.aguardando : VoiceUiState.erro,
    );
  }

  @override
  void dispose() {
    _processTimer?.cancel();
    super.dispose();
  }

  Future<bool> _confirmExecution(VoiceIntent intent) async {
    if (!intent.requiresConfirmation) return true;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar ação'),
          content: Text('Deseja executar: ${_actionText(intent)}?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Executar'),
            ),
          ],
        );
      },
    );
    return confirm ?? false;
  }

  String _actionText(VoiceIntent intent) {
    final target = intent.target ?? 'sem alvo';
    switch (intent.action) {
      case VoiceAction.abrirWhatsappContato:
        return 'Abrir WhatsApp com $target';
      case VoiceAction.ligarPara:
        return 'Ligar para $target';
      case VoiceAction.enviarMensagem:
        return 'Enviar mensagem para $target';
      case VoiceAction.abrirApp:
        return 'Abrir app $target';
      case VoiceAction.tocarMusica:
        return 'Tocar $target';
      case VoiceAction.navegar:
        return 'Navegar até $target';
      case VoiceAction.definirAlarme:
        return 'Definir alarme';
      case VoiceAction.pesquisarGoogle:
        return 'Pesquisar $target';
      case VoiceAction.voltar:
        return 'Voltar';
      case VoiceAction.fecharAplicativo:
        return 'Fechar aplicativo';
      case VoiceAction.mapearCelular:
        return 'Mapear celular';
      case VoiceAction.desconhecido:
        return 'Comando desconhecido';
    }
  }

  @override
  Widget build(BuildContext context) {
    final stateColor = _stateColor();
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset(
            'assets/images/voice_background.png',
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Colors.black.withValues(alpha: 0.04),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.30),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              child: Column(
                children: <Widget>[
                  Align(
                    alignment: Alignment.topRight,
                    child: _GlassPill(
                      borderColor: stateColor,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(Icons.graphic_eq, color: stateColor, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            _labelEstado(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(flex: 5),
                  GestureDetector(
                    onTap: _onMicTap,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width: 238,
                      height: 238,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: stateColor.withValues(
                            alpha: _state == VoiceUiState.aguardando
                                ? 0.32
                                : 0.78,
                          ),
                          width: _state == VoiceUiState.ouvindo ? 3 : 1.4,
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: stateColor.withValues(
                              alpha: _state == VoiceUiState.ouvindo
                                  ? 0.38
                                  : 0.14,
                            ),
                            blurRadius: _state == VoiceUiState.ouvindo
                                ? 38
                                : 22,
                            spreadRadius: _state == VoiceUiState.ouvindo
                                ? 8
                                : 2,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          _speechService.isListening
                              ? Icons.pause
                              : Icons.mic_none,
                          color: Colors.white.withValues(alpha: 0.16),
                          size: 82,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(flex: 2),
                  _GlassPill(
                    borderColor: stateColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 16,
                    ),
                    child: Text(
                      _promptText(),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _GlassPill(
                    borderColor: const Color(0xFF725CFF),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    child: Text(
                      _detectedAction,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 96),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassPill extends StatelessWidget {
  const _GlassPill({
    required this.child,
    required this.borderColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
  });

  final Widget child;
  final Color borderColor;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 340),
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xFF060719).withValues(alpha: 0.70),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor.withValues(alpha: 0.38)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: borderColor.withValues(alpha: 0.20),
            blurRadius: 22,
            spreadRadius: -4,
          ),
        ],
      ),
      child: child,
    );
  }
}
