import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // ✅ Still connecting
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF0A0E1A),
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFF00D4AA),
                strokeWidth: 2.5,
              ),
            ),
          );
        }

        // ✅ Not logged in → show Login
        if (!snapshot.hasData) {
          return const LoginPage();
        }

        // ✅ Logged in → show placeholder for now
        return const Scaffold(
          backgroundColor: Color(0xFF0A0E1A),
          body: Center(
            child: Text('Logged in!', style: TextStyle(color: Colors.white)),
          ),
        );
      },
    );
  }
}
