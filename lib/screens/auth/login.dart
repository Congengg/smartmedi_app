import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../widgets/common/blob_painter.dart';
import '../../widgets/common/gradient_button.dart';
import '../../widgets/common/app_input_field.dart';
import '../../widgets/common/app_logo.dart';
import 'register.dart';
import 'forgot_password.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _emailError;
  String? _passError;

  late AnimationController _blobCtrl;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

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
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _validate() {
    setState(() {
      _emailError = _emailCtrl.text.trim().isEmpty
          ? 'Email is required'
          : (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(_emailCtrl.text.trim())
                ? 'Enter a valid email'
                : null);
      _passError = _passCtrl.text.isEmpty
          ? 'Password is required'
          : (_passCtrl.text.length < 6 ? 'At least 6 characters' : null);
    });
    if (_emailError == null && _passError == null) _submit();
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      // TODO: Firebase Auth
      // final credential = await FirebaseAuth.instance
      //     .signInWithEmailAndPassword(
      //   email: _emailCtrl.text.trim(),
      //   password: _passCtrl.text,
      // );
      // final doc = await FirebaseFirestore.instance
      //     .collection('users')
      //     .doc(credential.user!.uid)
      //     .get();
      // final role = doc['role'];
      // if (mounted) {
      //   Navigator.pushReplacement(context, MaterialPageRoute(
      //     builder: (_) => role == 'doctor'
      //         ? const DoctorDashboardPage()
      //         : const PatientHomePage(),
      //   ));
      // }
      await Future.delayed(const Duration(seconds: 2));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: const Color(0xFFFF6B8A),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
            'Sign in to your account',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 13.5,
            ),
          ),
          const SizedBox(height: 28),

          // Email
          AppInputField(
            controller: _emailCtrl,
            label: 'Email address',
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            errorText: _emailError,
            onChanged: (_) => setState(() => _emailError = null),
          ),
          const SizedBox(height: 16),

          // Password
          AppInputField(
            controller: _passCtrl,
            label: 'Password',
            icon: Icons.lock_outline_rounded,
            obscureText: _obscure,
            errorText: _passError,
            onChanged: (_) => setState(() => _passError = null),
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

          // Forgot password
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
      child: OutlinedButton.icon(
        onPressed: () {
          // TODO: Google Sign-In
        },
        icon: Container(
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
        label: const Text(
          'Continue with Google',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14.5,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
          ),
        ),
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
