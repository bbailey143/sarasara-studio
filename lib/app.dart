import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ui/painting_screen.dart';

/// Root application widget.
///
/// Sets up the dark theme, system chrome, and routes to the painting
/// screen.
class SarasaraStudioApp extends StatelessWidget {
  const SarasaraStudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Immersive system chrome for painting.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    return MaterialApp(
      title: 'Sarasara Studio',
      debugShowCheckedModeBanner: false,

      // ── Dark Theme ──────────────────────────────────────────────
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF),
          brightness: Brightness.dark,
          surface: const Color(0xFF1C1C28),
        ),
        scaffoldBackgroundColor: const Color(0xFFFAF8F5),
        fontFamily: 'Roboto',
      ),

      home: const PaintingScreen(),
    );
  }
}
