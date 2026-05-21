import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/intent.dart';
import '../services/action_executor.dart';
import '../services/app_resolver.dart';
import '../services/contacts_service.dart';
import '../services/intent_parser.dart';
import '../services/speech_service.dart';
import '../services/tts_service.dart';
import '../services/user_preferences.dart';
import '../services/wake_service.dart';

enum VoiceUiState { aguardando, ouvindo, processando, executando, erro }

class VoiceCommandScreen extends StatefulWidget {
  const VoiceCommandScreen({super.key});

  @override
  State<VoiceCommandScreen> createState() => _VoiceCommandScreenState();
}

class _VoiceCommandScreenState extends State<VoiceCommandScreen>
    with TickerProviderStateMixin {
  final SpeechService _speechService = SpeechService();
  final TtsService _ttsService = TtsService();
  final IntentParser _intentParser = IntentParser();
  final ActionExecutor _executor = ActionExecutor(
    VoiceContactsService(),
    AppResolver(),
  );
  final WakeService _wakeService = WakeService();

  VoiceUiState _state = VoiceUiState.aguardando;
  bool _wakeEnabled = false;
  String _recognizedText = '';
  String _statusMessage = 'Toque no microfone para começar';
  Timer? _processTimer;
  String _lastProcessedText = '';

  late final AnimationController _pulseController;
  late final AnimationController _waveController;
  late final Animation<double> _pulseAnim;

  static const Color _accentBlue = Color(0xFF2CCBFF);
  static const Color _accentPurple = Color(0xFF835BFF);
  static const Color _accentGreen = Color(0xFF20E3B2);
  static const Color _accentRed = Color(0xFFFF5C8A);

  Color get _stateColor {
    switch (_state) {
      case VoiceUiState.aguardando:
        return _accentBlue;
      case VoiceUiState.ouvindo:
        return _accentPurple;
      case VoiceUiState.processando:
        return _accentPurple;
      case VoiceUiState.executando:
        return _accentGreen;
      case VoiceUiState.erro:
        return _accentRed;
    }
  }

  String get _hintText {
    switch (_state) {
      case VoiceUiState.aguardando:
        return _recognizedText.isNotEmpty
            ? _recognizedText
            : 'Diga: "Abrir WhatsApp"';
      case VoiceUiState.ouvindo:
        return _recognizedText.isNotEmpty ? _recognizedText : 'Ouvindo...';
      case VoiceUiState.processando:
        return 'Processando...';
      case VoiceUiState.executando:
        return 'Executando...';
      case VoiceUiState.erro:
        return _statusMessage;
    }
  }

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _pulseAnim = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _setupAndStart();
  }

  Future<void> _setupAndStart() async {
    await _ttsService.initialize();
    await _requestPermissions();
    await _speechService.initialize();
    if (mounted) await _autoRestartListening();
  }

  Future<void> _requestPermissions() async {
    await Permission.microphone.request();
    await Permission.contacts.request();
    await Permission.notification.request();
  }

  Future<void> _toggleWakeMode() async {
    if (_wakeEnabled) {
      await _wakeService.stop();
      setState(() => _wakeEnabled = false);
      await _ttsService.speak('Modo escuta desligado.');
    } else {
      final word = await UserPreferences.getWakeWord() ?? 'bruno';
      final started = await _wakeService.start(wakeWord: word);
      setState(() => _wakeEnabled = started);
      if (started) {
        await _ttsService.speak(
          'Escutando ativo. Diga $word mais o comando.',
        );
      } else {
        await _ttsService.speak(
          'Não foi possível iniciar o modo escuta.',
        );
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    _processTimer?.cancel();
    _speechService.stopListening();
    _wakeService.stop();
    super.dispose();
  }

  Future<void> _onMicTap() async {
    if (_speechService.isListening) {
      await _speechService.stopListening();
      setState(() => _state = VoiceUiState.aguardando);
      return;
    }
    await _autoRestartListening();
  }

  Future<void> _processRecognizedText(String text) async {
    final normalized = text.trim().toLowerCase();
    if (normalized.isEmpty || normalized == _lastProcessedText) return;
    _lastProcessedText = normalized;
    _processTimer?.cancel();
    await _speechService.stopListening();
    await _process(text);
    if (mounted) await _autoRestartListening();
  }

  Future<void> _autoRestartListening() async {
    if (!_speechService.isListening) {
      setState(() {
        _state = VoiceUiState.ouvindo;
        _recognizedText = '';
      });
      await _speechService.startListening(
        onResult: (String text, bool isFinal) async {
          setState(() => _recognizedText = text);
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
  }

  Future<void> _process(String text) async {
    setState(() => _state = VoiceUiState.processando);
    final intent = await _intentParser.parse(text);

    if (!intent.isKnown) {
      setState(() {
        _state = VoiceUiState.erro;
        _statusMessage = 'Não entendi, tente novamente.';
      });
      await _ttsService.speak('Não consegui entender, tente novamente.');
      return;
    }

    if (intent.ambiguous) {
      setState(() {
        _state = VoiceUiState.erro;
        _statusMessage = intent.confirmationQuestion ?? 'Comando ambíguo.';
      });
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
        final top = matches.take(2).map((m) => m.name).join(' e ');
        setState(() {
          _state = VoiceUiState.aguardando;
          _statusMessage = 'Encontrei $top, qual você quer?';
        });
        await _ttsService.speak('Encontrei $top, qual você quer?');
        return;
      }
    }

    final canRun = await _confirmExecution(intent);
    if (!canRun) return;

    setState(() => _state = VoiceUiState.executando);
    final result = await _executor.execute(intent);
    await _ttsService.speak(result.message);
    setState(() {
      _state = result.success ? VoiceUiState.aguardando : VoiceUiState.erro;
      _statusMessage = result.message;
    });
  }

  Future<bool> _confirmExecution(VoiceIntent intent) async {
    if (!intent.requiresConfirmation) return true;
    await _speechService.stopListening();
    if (!mounted) return true;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0D0F1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: _accentPurple.withValues(alpha: 0.4)),
        ),
        title: const Text(
          'Confirmar ação',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: Text(
          intent.confirmationQuestion ?? 'Deseja executar esse comando?',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancelar',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _accentPurple,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    return confirm ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final color = _stateColor;
    final isListening = _state == VoiceUiState.ouvindo;

    return Scaffold(
      backgroundColor: const Color(0xFF07091A),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            const SizedBox(height: 24),

            // Sound wave
            SizedBox(
              height: 48,
              child: AnimatedBuilder(
                animation: _waveController,
                builder: (ctx, _) => CustomPaint(
                  size: const Size(double.infinity, 48),
                  painter: _SoundWavePainter(
                    progress: _waveController.value,
                    active: isListening,
                    color: color,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                    color: Colors.white,
                  ),
                  children: <InlineSpan>[
                    const TextSpan(text: 'Seu celular,\n'),
                    WidgetSpan(
                      child: ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: <Color>[Color(0xFF2CCBFF), Color(0xFF835BFF)],
                        ).createShader(bounds),
                        child: const Text(
                          'comandado',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const TextSpan(text: '\npela sua voz.'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Subtitle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Fale o que você precisa,\nele faz tudo por você.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  height: 1.5,
                ),
              ),
            ),

            const Spacer(),

            // Mic button
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, child) => Transform.scale(
                scale: isListening ? _pulseAnim.value : 1.0,
                child: child,
              ),
              child: GestureDetector(
                onTap: _onMicTap,
                child: SizedBox(
                  width: 220,
                  height: 220,
                  child: CustomPaint(
                    painter: _MicRingPainter(color: color, active: isListening),
                    child: Center(
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: <Color>[
                              color.withValues(alpha: 0.25),
                              const Color(0xFF0D0F2A),
                            ],
                          ),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: color.withValues(alpha: 0.5),
                              blurRadius: 30,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: Icon(
                          _state == VoiceUiState.ouvindo
                              ? Icons.pause_rounded
                              : Icons.mic_rounded,
                          color: Colors.white,
                          size: 52,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const Spacer(),

            // Hint / recognized text pill
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D0F2A).withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: color.withValues(alpha: 0.35),
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: color.withValues(alpha: 0.15),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Text(
                  _hintText,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Wake Word (Bruno) toggle button
            GestureDetector(
              onTap: _toggleWakeMode,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: _wakeEnabled
                      ? const Color(0xFF20E3B2).withValues(alpha: 0.15)
                      : const Color(0xFF835BFF).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _wakeEnabled
                        ? const Color(0xFF20E3B2).withValues(alpha: 0.6)
                        : const Color(0xFF835BFF).withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(
                      _wakeEnabled
                          ? Icons.mic_external_on_rounded
                          : Icons.mic_none_rounded,
                      color: _wakeEnabled
                          ? const Color(0xFF20E3B2)
                          : const Color(0xFF835BFF),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _wakeEnabled
                          ? 'Bruno está escutando (ativo)'
                          : 'Ativar Bruno (wake word)',
                      style: TextStyle(
                        color: _wakeEnabled
                            ? const Color(0xFF20E3B2).withValues(alpha: 0.95)
                            : const Color(0xFF835BFF).withValues(alpha: 0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Bottom bar
            Container(
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0D0F2A).withValues(alpha: 0.6),
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: const <Widget>[
                  _BottomFeature(icon: Icons.bolt_rounded, label: 'Rápido'),
                  _BottomFeature(
                    icon: Icons.psychology_rounded,
                    label: 'Inteligente',
                  ),
                  _BottomFeature(
                    icon: Icons.location_on_rounded,
                    label: 'Prático',
                  ),
                  _BottomFeature(
                    icon: Icons.verified_user_rounded,
                    label: 'Seguro',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomFeature extends StatelessWidget {
  const _BottomFeature({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, color: Colors.white.withValues(alpha: 0.5), size: 22),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _MicRingPainter extends CustomPainter {
  const _MicRingPainter({required this.color, required this.active});

  final Color color;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2;

    // Outer glow ring
    canvas.drawCircle(
      center,
      outerRadius - 4,
      Paint()
        ..color = color.withValues(alpha: active ? 0.18 : 0.08)
        ..style = PaintingStyle.fill,
    );

    // Outer ring stroke
    canvas.drawCircle(
      center,
      outerRadius - 4,
      Paint()
        ..color = color.withValues(alpha: active ? 0.8 : 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = active ? 2.5 : 1.5,
    );

    // Inner ring
    canvas.drawCircle(
      center,
      outerRadius * 0.72,
      Paint()
        ..color = color.withValues(alpha: active ? 0.5 : 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  @override
  bool shouldRepaint(_MicRingPainter old) =>
      old.color != color || old.active != active;
}

class _SoundWavePainter extends CustomPainter {
  const _SoundWavePainter({
    required this.progress,
    required this.active,
    required this.color,
  });

  final double progress;
  final bool active;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const barCount = 28;
    final barWidth = (size.width / barCount) * 0.55;
    final spacing = size.width / barCount;
    final centerY = size.height / 2;
    final paint = Paint()
      ..color = color.withValues(alpha: 0.75)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barWidth;

    for (var i = 0; i < barCount; i++) {
      final x = i * spacing + spacing / 2;
      final phase = (i / barCount) + progress;
      final amplitude = active
          ? 0.35 + 0.65 * math.pow(math.sin(phase * math.pi * 2).abs(), 0.5)
          : 0.15 + 0.15 * math.sin(phase * math.pi * 2).abs();
      final barHeight = size.height * amplitude;
      canvas.drawLine(
        Offset(x, centerY - barHeight / 2),
        Offset(x, centerY + barHeight / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_SoundWavePainter old) =>
      old.progress != progress || old.active != active || old.color != color;
}
