import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import '../../widgets/common/blob_painter.dart';
import '../../widgets/common/gradient_button.dart';
import '../../widgets/common/app_input_field.dart';
import '../../widgets/common/top_bar.dart';
import '../../widgets/auth/resend_timer.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage>
    with TickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  String? _emailError;
  bool _loading = false;
  bool _emailSent = false;

  late AnimationController _blobCtrl;
  late AnimationController _fadeCtrl;
  late AnimationController _successCtrl;

  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  late Animation<double> _successScaleAnim;
  late Animation<double> _successFadeAnim;

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

    _successCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut));

    _successScaleAnim = Tween<double>(
      begin: 0.6,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _successCtrl, curve: Curves.elasticOut));
    _successFadeAnim = CurvedAnimation(
      parent: _successCtrl,
      curve: Curves.easeOut,
    );

    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) _fadeCtrl.forward();
    });
  }

  @override
  void dispose() {
    _blobCtrl.dispose();
    _fadeCtrl.dispose();
    _successCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  // ─── Validation ──────────────────────────────────────────────────────────────
  void _validate() {
    setState(() {
      _emailError = _emailCtrl.text.trim().isEmpty
          ? 'Email is required'
          : (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(_emailCtrl.text.trim())
                ? 'Enter a valid email address'
                : null);
    });
    if (_emailError == null) _sendReset();
  }

  // ─── Send reset email via Firebase ───────────────────────────────────────────
  Future<void> _sendReset() async {
    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailCtrl.text.trim(),
      );

      if (mounted) {
        setState(() {
          _loading = false;
          _emailSent = true;
        });
        _successCtrl.forward();
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _showError(_friendlyError(e.code));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _showError('Something went wrong. Please try again.');
      }
    }
  }

  // ─── Resend reset email (called by ResendTimer widget) ────────────────────────
  Future<void> _resendReset() async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailCtrl.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                SizedBox(width: 10),
                Text(
                  'Reset email resent!',
                  style: TextStyle(color: Colors.white, fontSize: 13.5),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF00D4AA),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) _showError(_friendlyError(e.code));
    } catch (_) {
      if (mounted) _showError('Could not resend. Please try again.');
    }
  }

  // ─── Map Firebase error codes → friendly messages ─────────────────────────────
  String _friendlyError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email address.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'No internet connection. Check your network.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }

  // ─── Show error snackbar ─────────────────────────────────────────────────────
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
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
        backgroundColor: const Color(0xFFFF6B8A),
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
                  blobs: AppBlobs.forgotPassword,
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
                      const Color(0xFF0A0E1A).withValues(alpha: 0.92),
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
                        child: _emailSent
                            ? _buildSuccessState()
                            : _buildFormState(),
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

  Widget _buildFormState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 16),
        const TopBar(),
        const SizedBox(height: 44),
        _buildIconBadge(
          icon: Icons.lock_reset_rounded,
          color: const Color(0xFF00D4AA),
        ),
        const SizedBox(height: 28),
        const Text(
          'Forgot Password?',
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'No worries! Enter your email and we\'ll\nsend you a reset link.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 14,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 40),
        Container(
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
              Text(
                'Email address',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 13,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 10),
              AppInputField(
                controller: _emailCtrl,
                label: 'Enter your email',
                icon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                errorText: _emailError,
                onChanged: (_) => setState(() => _emailError = null),
              ),
              const SizedBox(height: 24),
              GradientButton(
                label: 'Send Reset Link',
                loading: _loading,
                onPressed: _validate,
                icon: Icons.send_rounded,
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        _buildTips(),
        const SizedBox(height: 36),
        _buildBackToLoginLink(),
        const SizedBox(height: 28),
      ],
    );
  }

  Widget _buildSuccessState() {
    return ScaleTransition(
      scale: _successScaleAnim,
      child: FadeTransition(
        opacity: _successFadeAnim,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 60),
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00D4AA), Color(0xFF00A896)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00D4AA).withValues(alpha: 0.40),
                    blurRadius: 32,
                    spreadRadius: 4,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.mark_email_read_rounded,
                color: Colors.white,
                size: 48,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Check your email!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 12),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 14,
                  height: 1.7,
                ),
                children: [
                  const TextSpan(text: 'We sent a password reset link to\n'),
                  TextSpan(
                    text: _emailCtrl.text.trim(),
                    style: const TextStyle(
                      color: Color(0xFF00D4AA),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.09),
                  width: 1.2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Next steps',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 12.5,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildStep(
                    number: '1',
                    text: 'Open the email from SmartMedi',
                  ),
                  _buildStep(
                    number: '2',
                    text: 'Click the "Reset Password" button',
                  ),
                  _buildStep(
                    number: '3',
                    text: 'Create your new password',
                    isLast: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ✅ ResendTimer now wired to real Firebase call
            ResendTimer(onResend: _resendReset),

            const SizedBox(height: 32),
            GradientButton(
              label: 'Back to Sign In',
              loading: false,
              onPressed: () => Navigator.pop(context),
              icon: Icons.arrow_back_rounded,
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildStep({
    required String number,
    required String text,
    bool isLast = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFF00D4AA).withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF00D4AA).withValues(alpha: 0.40),
                  width: 1.2,
                ),
              ),
              child: Center(
                child: Text(
                  number,
                  style: const TextStyle(
                    color: Color(0xFF00D4AA),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            if (!isLast)
              Container(
                width: 1.5,
                height: 20,
                margin: const EdgeInsets.symmetric(vertical: 4),
                color: const Color(0xFF00D4AA).withValues(alpha: 0.20),
              ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.70),
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIconBadge({required IconData icon, required Color color}) {
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.30), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.20),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Icon(icon, color: color, size: 40),
    );
  }

  Widget _buildTips() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF5B6EF5).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF5B6EF5).withValues(alpha: 0.20),
          width: 1.2,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: Color(0xFF8B9CF5),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Didn\'t receive the email?',
                  style: TextStyle(
                    color: Color(0xFF8B9CF5),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '• Check your spam or junk folder\n'
                  '• Make sure the email address is correct\n'
                  '• Allow up to 2 minutes for delivery',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 12.5,
                    height: 1.7,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackToLoginLink() {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.arrow_back_rounded,
            color: Colors.white.withValues(alpha: 0.45),
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            'Back to Sign In',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 13.5,
            ),
          ),
        ],
      ),
    );
  }
}
