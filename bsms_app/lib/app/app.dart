import 'package:flutter/material.dart';

/// Main application widget for the BSMS ECG monitoring system.
/// 
/// Provides:
/// - Material Design theme and styling
/// - Navigation structure for the app
/// - Top-level state management setup
/// 
/// The app will display:
/// - Live ECG screen (primary view)
/// - Device connection screen (setup flow)
/// - Session history list
/// - Settings and about screens
class BsmsApp extends StatelessWidget {
  const BsmsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BSMS ECG Monitor',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 2,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 2,
        ),
      ),
      themeMode: ThemeMode.system,
      home: const BsmsHomePage(),
    );
  }
}

/// Home page placeholder for the BSMS app.
/// 
/// This will be replaced with the actual navigation structure
/// once Dev C implements the presentation layer screens.
class BsmsHomePage extends StatelessWidget {
  const BsmsHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BSMS ECG Monitor'),
      ),
      body: const Center(
        child: Text(
          'ECG Monitor Application\n\nDev C: Implement presentation layer',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
