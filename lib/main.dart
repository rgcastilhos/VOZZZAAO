import 'package:flutter/material.dart';

import 'screens/voice_command_screen.dart';

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
      home: const VoiceCommandScreen(),
    );
  }
}
