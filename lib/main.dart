import 'package:flutter/material.dart';

import 'screens/voice_command_screen.dart';

void main() {
  runApp(const VozComandoApp());
}

class VozComandoApp extends StatelessWidget {
  const VozComandoApp({super.key});

  // This widget is the root of your application.
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
