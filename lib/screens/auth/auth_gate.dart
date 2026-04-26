import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../home.dart';
import 'login.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  /// Tracks whether we've finished the cold-start sign-out.
  /// Until this is true we show a splash — never the home page.
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _forceLogoutOnColdStart();
  }

  /// Sign out any persisted Firebase session the moment the app launches.
  /// This guarantees the user always sees the login screen on a fresh open.
  Future<void> _forceLogoutOnColdStart() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        context.read<UserProvider>().clear();
      }
    } catch (_) {
      // sign-out failure is non-fatal — just proceed
    } finally {
      if (mounted) setState(() => _ready = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ── Cold-start splash (signing out in background) ──────────────────────
    if (!_ready) {
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

    // ── After sign-out completes, stream drives the UI ─────────────────────
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {

        // Still resolving auth state
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

        // Not logged in → show Login
        if (!snapshot.hasData) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.read<UserProvider>().clear();
          });
          return const LoginPage();
        }

        // Logged in (user signed in during this session) → load and go home
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final provider = context.read<UserProvider>();
          if (!provider.isLoading) provider.loadUser();
        });

        return const PatientHomePage();
      },
    );
  }
}