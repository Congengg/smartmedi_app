import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../home.dart';
import 'login.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {

        // ── Still connecting to Firebase ───────────────────────────────────
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

        // ── Not logged in → clear provider + show Login ────────────────────
        if (!snapshot.hasData) {
          // Use addPostFrameCallback so clear() runs AFTER build finishes
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.read<UserProvider>().clear();
          });
          return const LoginPage();
        }

        // ── Logged in → load user data after build completes ──────────────
        // addPostFrameCallback prevents "setState called during build" error
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final userProvider = context.read<UserProvider>();
          if (userProvider.isLoading) {
            userProvider.loadUser();
          }
        });

        return const PatientHomePage();
      },
    );
  }
}