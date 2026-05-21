import 'package:flutter/material.dart';

import 'screens/onboarding_screen.dart';
import 'screens/voice_command_screen.dart';
import 'services/user_preferences.dart';

void main() {
  runApp(const VozComandoApp());
}

class VozComandoApp extends StatelessWidget {
  const VozComandoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VozComando',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueAccent,
          brightness: Brightness.dark,
        ),
      ),
      home: const _AppRouter(),
    );
  }
}

class _AppRouter extends StatelessWidget {
  const _AppRouter();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: UserPreferences.isFirstRun(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF07091A),
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFF835BFF),
              ),
            ),
          );
        }
        final isFirstRun = snapshot.data ?? true;
        return isFirstRun
            ? const OnboardingScreen()
            : const VoiceCommandScreen();
      },
    );
  }
}
