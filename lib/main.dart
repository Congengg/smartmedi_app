import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'providers/user_provider.dart';
import 'screens/auth/auth_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const SmartMediApp());
}

class SmartMediApp extends StatelessWidget {
  const SmartMediApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        // Add more providers here as the app grows:
        // ChangeNotifierProvider(create: (_) => AppointmentProvider()),
        // ChangeNotifierProvider(create: (_) => SymptomProvider()),
      ],
      child: MaterialApp(
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
        home: const AuthGate(), // ✅ AuthGate handles routing automatically
      ),
    );
  }
}