import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:smartmedi_app/screens/home.dart';
import '../../providers/user_provider.dart';
import '../../widgets/common/blob_painter.dart';
import '../../widgets/common/gradient_button.dart';
import '../../widgets/common/app_input_field.dart';
import '../../widgets/common/app_logo.dart';
import '../../services/google_auth_service.dart';
import 'register.dart';
import 'forgot_password.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final _loginCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  bool _googleLoading = false;
  String? _loginError;
  String? _passError;

  // ─── Inline error shown under the field (not snackbar) ──────────────────────
  // Used when Firebase knows which field is wrong.

  late AnimationController _blobCtrl;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  // ─── Firebase error code → friendly message MAP ───────────────────────────
  // Easier to maintain than switch — add/remove codes in one place.
  static const Map<String, String> _firebaseErrors = {
    'user-not-found': 'No account found with this email.',
    'wrong-password': 'Incorrect password. Please try again.',
    'invalid-credential': 'Incorrect email/username or password.',
    'user-disabled': 'This account has been disabled. Contact support.',
    'too-many-requests': 'Too many attempts. Please try again later.',
    'network-request-failed': 'No internet connection. Check your network.',
    'invalid-email': 'The email address format is not valid.',
    'operation-not-allowed': 'Email/password sign-in is not enabled.',
  };

  // ─── Which Firebase codes should highlight a specific field ──────────────
  static const Set<String> _passRelatedErrors = {
    'wrong-password',
    'invalid-credential',
  };
  static const Set<String> _emailRelatedErrors = {
    'user-not-found',
    'invalid-email',
    'user-disabled',
  };

  @override
  void initState() {
    super.initState();
    _blobCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut));

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _fadeCtrl.forward();
    });
  }

  @override
  void dispose() {
    _blobCtrl.dispose();
    _fadeCtrl.dispose();
    _loginCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  // ─── Handle a Firebase error code ────────────────────────────────────────
  // Looks up the message from the map, then decides WHERE to show it:
  //   • password-related → red border + inline text under password field
  //   • email-related    → red border + inline text under login field
  //   • everything else  → floating snackbar
  void _handleFirebaseError(String code) {
    final message =
        _firebaseErrors[code] ?? 'Something went wrong. Please try again.';

    if (_passRelatedErrors.contains(code)) {
      setState(() => _passError = message);
    } else if (_emailRelatedErrors.contains(code)) {
      setState(() => _loginError = message);
    } else {
      _showSnackbar(message, isError: true);
    }
  }

  // ─── Validate fields ───────────────────────────────────────────────────────
  bool _isEmail(String input) => RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(input);

  void _validate() {
    // Clear previous errors first
    setState(() {
      _loginError = null;
      _passError = null;

      final input = _loginCtrl.text.trim();
      if (input.isEmpty) {
        _loginError = 'Email or username is required';
      } else if (input.contains('@') && !_isEmail(input)) {
        _loginError = 'Enter a valid email address';
      } else if (!input.contains('@') && input.length < 3) {
        _loginError = 'Username must be at least 3 characters';
      }

      if (_passCtrl.text.isEmpty) {
        _passError = 'Password is required';
      } else if (_passCtrl.text.length < 6) {
        _passError = 'At least 6 characters';
      }
    });

    if (_loginError == null && _passError == null) _submit();
  }

  // ─── Resolve username → email ─────────────────────────────────────────────
  Future<String?> _resolveEmail(String input) async {
    if (_isEmail(input)) return input;
    final query = await FirebaseFirestore.instance
        .collection('users')
        .where('username', isEqualTo: input.toLowerCase())
        .limit(1)
        .get();
    if (query.docs.isEmpty) return null;
    return query.docs.first.data()['email'] as String?;
  }

  // ─── Firebase email/password login ────────────────────────────────────────
  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      final input = _loginCtrl.text.trim();
      final email = await _resolveEmail(input);

      if (email == null) {
        // Username not found — show under the login field
        setState(() => _loginError = 'No account found with that username.');
        return;
      }

      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: _passCtrl.text,
      );

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(credential.user!.uid)
          .get();

      if (!doc.exists) {
        await FirebaseAuth.instance.signOut();
        setState(
          () => _loginError = 'Account not found. Please register first.',
        );
        return;
      }

      final role = doc.data()?['role'] ?? '';
      if (role == 'doctor') {
        await FirebaseAuth.instance.signOut();
        _showSnackbar(
          'Doctor accounts must use the SmartMedi Web Portal to log in.',
          isError: true,
        );
        return;
      }

      if (mounted) {
        await context.read<UserProvider>().loadUser();
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const PatientHomePage()),
        );
        _showSnackbar(
          'Welcome back, ${doc.data()?['name'] ?? ''}!',
          isError: false,
        );
      }
    } on FirebaseAuthException catch (e) {
      // ✅ Use the map-based handler instead of switch
      _handleFirebaseError(e.code);
    } catch (_) {
      _showSnackbar('Something went wrong. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ─── Google Sign-In ───────────────────────────────────────────────────────
  Future<void> _googleSignIn() async {
    setState(() => _googleLoading = true);
    final result = await GoogleAuthService.signIn();
    if (!mounted) return;
    setState(() => _googleLoading = false);

    // Map-style handling using a simple lookup instead of switch
    final handlers = <GoogleAuthStatus, void Function()>{
      GoogleAuthStatus.success: () async {
        await context.read<UserProvider>().loadUser();
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const PatientHomePage()),
        );
        _showSnackbar('Welcome, ${result.name ?? ''}!', isError: false);
      },
      GoogleAuthStatus.cancelled: () {},
      GoogleAuthStatus.doctorBlocked: () =>
          _showSnackbar(result.message!, isError: true),
      GoogleAuthStatus.error: () =>
          _showSnackbar(result.message!, isError: true),
    };

    handlers[result.status]?.call();
  }

  // ─── Single snackbar helper ───────────────────────────────────────────────
  void _showSnackbar(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 13.5),
              ),
            ),
          ],
        ),
        backgroundColor: isError
            ? const Color(0xFFFF6B8A)
            : const Color(0xFF00D4AA),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: AnimatedBuilder(
        animation: _blobCtrl,
        builder: (context, _) {
          return Stack(
            children: [
              CustomPaint(
                painter: BlobPainter(
                  _blobCtrl.value * 2 * math.pi,
                  blobs: AppBlobs.login,
                ),
                size: MediaQuery.of(context).size,
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF0A0E1A).withValues(alpha: 0.55),
                      const Color(0xFF0A0E1A).withValues(alpha: 0.90),
                    ],
                  ),
                ),
              ),
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: SlideTransition(
                        position: _slideAnim,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const SizedBox(height: 32),
                            const AppLogo(),
                            const SizedBox(height: 40),
                            _buildCard(),
                            const SizedBox(height: 28),
                            _buildDivider(),
                            const SizedBox(height: 20),
                            _buildGoogleButton(),
                            const SizedBox(height: 32),
                            _buildSignUpLink(),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCard() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.09),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 40,
            spreadRadius: -4,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Welcome back 👋',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Sign in with your email or username',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 13.5,
            ),
          ),
          const SizedBox(height: 28),

          AppInputField(
            controller: _loginCtrl,
            label: 'Email or username',
            icon: Icons.person_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            errorText: _loginError,
            onChanged: (_) => setState(() {
              _loginError = null;
            }),
          ),
          const SizedBox(height: 16),

          AppInputField(
            controller: _passCtrl,
            label: 'Password',
            icon: Icons.lock_outline_rounded,
            obscureText: _obscure,
            errorText: _passError,
            onChanged: (_) => setState(() {
              _passError = null;
            }),
            suffix: IconButton(
              onPressed: () => setState(() => _obscure = !_obscure),
              icon: Icon(
                _obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: Colors.white.withValues(alpha: 0.4),
                size: 20,
              ),
            ),
          ),

          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ForgotPasswordPage()),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              ),
              child: const Text(
                'Forgot password?',
                style: TextStyle(
                  color: Color(0xFF00D4AA),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          GradientButton(
            label: 'Sign In',
            loading: _loading,
            onPressed: _validate,
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(
          child: Divider(
            color: Colors.white.withValues(alpha: 0.12),
            thickness: 1,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'or continue with',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.35),
              fontSize: 12.5,
              letterSpacing: 0.2,
            ),
          ),
        ),
        Expanded(
          child: Divider(
            color: Colors.white.withValues(alpha: 0.12),
            thickness: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildGoogleButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: _googleLoading ? null : _googleSignIn,
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.15),
            width: 1.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          backgroundColor: Colors.white.withValues(alpha: 0.05),
        ),
        child: _googleLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.2,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text(
                        'G',
                        style: TextStyle(
                          color: Color(0xFF4285F4),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Continue with Google',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildSignUpLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Don't have an account? ",
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 13.5,
          ),
        ),
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RegisterPage()),
          ),
          child: const Text(
            'Sign Up',
            style: TextStyle(
              color: Color(0xFF00D4AA),
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
