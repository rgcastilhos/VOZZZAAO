import 'package:flutter/material.dart';

import '../services/user_preferences.dart';
import 'voice_command_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<String> _suggestions = <String>[
    'Bruno',
    'Alexa',
    'Jarvis',
    'Mestre',
    'Chefe',
    'Capitão',
    'Boss',
  ];

  static const Color _accentPurple = Color(0xFF835BFF);
  static const Color _accentGreen = Color(0xFF20E3B2);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveAndGo() async {
    final word = _controller.text.trim();
    if (word.isEmpty) return;
    await UserPreferences.setWakeWord(word);
    await UserPreferences.markFirstRunComplete();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => const VoiceCommandScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07091A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SizedBox(height: 48),

              // Title
              const Text(
                'Como você quer me chamar?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Escolha uma palavra que você vai falar sempre que quiser me chamar.\nExemplo: "Ei Bruno, abrir WhatsApp"',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 36),

              // Text field
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0D0F2A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _accentPurple.withValues(alpha: 0.4),
                  ),
                ),
                child: TextField(
                  controller: _controller,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Digite sua palavra...',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 20,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 20,
                    ),
                  ),
                  onSubmitted: (_) => _saveAndGo(),
                ),
              ),
              const SizedBox(height: 24),

              // Suggestions
              Text(
                'Sugestões:',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _suggestions.map((word) {
                  return GestureDetector(
                    onTap: () {
                      _controller.text = word;
                      _saveAndGo();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: _accentPurple.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _accentPurple.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        word,
                        style: TextStyle(
                          color: _accentPurple.withValues(alpha: 0.95),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const Spacer(),

              // Continue button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _accentGreen,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _saveAndGo,
                  child: const Text(
                    'Continuar',
                    style: TextStyle(
                      color: Color(0xFF07091A),
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
