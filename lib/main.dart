import 'package:flutter/material.dart';
import 'screens/auth/login.dart';

void main() {
  runApp(const SmartMediApp());
}

class SmartMediApp extends StatelessWidget {
  const SmartMediApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartMedi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'SF Pro Display',
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00D4AA),
          surface: Color(0xFF0A0E1A),
        ),
        useMaterial3: true,
      ),
      home: const LoginPage(),
    );
  }
}
