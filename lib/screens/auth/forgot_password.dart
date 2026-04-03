import 'package:flutter/material.dart';
import 'dart:math' as math;

// ─── Animated blob background painter ────────────────────────────────────────
class _BlobPainter extends CustomPainter {
  final double t;
  _BlobPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Blob 1 — teal (top right)
    paint.color = const Color(0xFF00D4AA).withOpacity(0.15);
    final c1 = Offset(
      size.width * (0.88 + 0.06 * math.sin(t)),
      size.height * (0.10 + 0.05 * math.cos(t * 0.8)),
    );
    canvas.drawCircle(c1, size.width * 0.36, paint);

    // Blob 2 — indigo (left middle)
    paint.color = const Color(0xFF5B6EF5).withOpacity(0.13);
    final c2 = Offset(
      size.width * (0.08 + 0.06 * math.cos(t * 0.9)),
      size.height * (0.55 + 0.06 * math.sin(t * 1.1)),
    );
    canvas.drawCircle(c2, size.width * 0.38, paint);

    // Blob 3 — rose (bottom center)
    paint.color = const Color(0xFFE040A0).withOpacity(0.09);
    final c3 = Offset(
      size.width * (0.50 + 0.05 * math.sin(t * 1.3)),
      size.height * (0.90 + 0.04 * math.cos(t * 0.7)),
    );
    canvas.drawCircle(c3, size.width * 0.32, paint);
  }

  @override
  bool shouldRepaint(_BlobPainter old) => old.t != t;
}

// ─── Forgot Password Page ─────────────────────────────────────────────────────
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
  bool _emailSent = false; // flips to show success state

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

    _successScaleAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _successCtrl, curve: Curves.elasticOut),
    );
    _successFadeAnim = CurvedAnimation(
      parent: _successCtrl,
      curve: Curves.easeOut,
    );

    Future.delayed(const Duration(milliseconds: 150), () {
      _fadeCtrl.forward();
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

  // ─── Validate & send ────────────────────────────────────────────────────────
  void _validate() {
    setState(() {
      _emailError = _emailCtrl.text.trim().isEmpty
          ? 'Email is required'
          : (!_emailCtrl.text.contains('@')
              ? 'Enter a valid email address'
              : null);
    });
    if (_emailError == null) _sendReset();
  }

  Future<void> _sendReset() async {
    setState(() => _loading = true);
    await Future.delayed(const Duration(seconds: 2));
    // TODO: Replace with Firebase Auth
    // await FirebaseAuth.instance.sendPasswordResetEmail(
    //   email: _emailCtrl.text.trim(),
    // );
    if (mounted) {
      setState(() {
        _loading = false;
        _emailSent = true;
      });
      _successCtrl.forward();
    }
  }

  // ─── Input decoration ────────────────────────────────────────────────────────
  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    String? error,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: Colors.white.withOpacity(0.5),
        fontSize: 14,
        letterSpacing: 0.3,
      ),
      prefixIcon: Icon(icon, color: const Color(0xFF00D4AA), size: 20),
      errorText: error,
      errorStyle: const TextStyle(color: Color(0xFFFF6B8A), fontSize: 12),
      filled: true,
      fillColor: Colors.white.withOpacity(0.06),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: Colors.white.withOpacity(0.10),
          width: 1.2,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF00D4AA), width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFFF6B8A), width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFFF6B8A), width: 1.6),
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
              // Animated blobs
              CustomPaint(
                painter: _BlobPainter(_blobCtrl.value * 2 * math.pi),
                size: MediaQuery.of(context).size,
              ),

              // Gradient overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF0A0E1A).withOpacity(0.55),
                      const Color(0xFF0A0E1A).withOpacity(0.92),
                    ],
                  ),
                ),
              ),

              // Content
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

  // ─── Form state ─────────────────────────────────────────────────────────────
  Widget _buildFormState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 16),
        _buildTopBar(),
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
            color: Colors.white.withOpacity(0.45),
            fontSize: 14,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 40),

        // ── Card ──────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withOpacity(0.09),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
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
                  color: Colors.white.withOpacity(0.55),
                  fontSize: 13,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: _inputDecoration(
                  label: 'Enter your email',
                  icon: Icons.mail_outline_rounded,
                  error: _emailError,
                ),
                onChanged: (_) => setState(() => _emailError = null),
              ),
              const SizedBox(height: 24),

              // Send reset button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: _loading
                    ? Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00D4AA), Color(0xFF00A896)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          ),
                        ),
                      )
                    : DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00D4AA), Color(0xFF00A896)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  const Color(0xFF00D4AA).withOpacity(0.35),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: _validate,
                          icon: const Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                          label: const Text(
                            'Send Reset Link',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // ── Tips section ───────────────────────────────────────────────────
        _buildTips(),
        const SizedBox(height: 36),

        // ── Back to login ──────────────────────────────────────────────────
        _buildBackToLogin(),
        const SizedBox(height: 28),
      ],
    );
  }

  // ─── Success state ──────────────────────────────────────────────────────────
  Widget _buildSuccessState() {
    return ScaleTransition(
      scale: _successScaleAnim,
      child: FadeTransition(
        opacity: _successFadeAnim,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 60),

            // Animated check icon
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
                    color: const Color(0xFF00D4AA).withOpacity(0.40),
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

            // Shows the email that was entered
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: TextStyle(
                  color: Colors.white.withOpacity(0.45),
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

            // ── Steps card ─────────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.09),
                  width: 1.2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Next steps',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.55),
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

            // ── Resend option ──────────────────────────────────────────────
            _ResendTimer(
              onResend: () async {
                setState(() => _loading = true);
                await Future.delayed(const Duration(seconds: 1));
                if (mounted) setState(() => _loading = false);
                // TODO: FirebaseAuth.instance.sendPasswordResetEmail(...)
              },
            ),
            const SizedBox(height: 32),

            // ── Back to login ──────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 54,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00D4AA), Color(0xFF00A896)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00D4AA).withOpacity(0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  label: const Text(
                    'Back to Sign In',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ─── Step row ──────────────────────────────────────────────────────────────
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
                color: const Color(0xFF00D4AA).withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF00D4AA).withOpacity(0.40),
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
                color: const Color(0xFF00D4AA).withOpacity(0.20),
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
                color: Colors.white.withOpacity(0.70),
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Top bar (back + logo) ──────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.10),
                width: 1,
              ),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
        ),
        const Spacer(),
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF00D4AA), Color(0xFF00A896)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00D4AA).withOpacity(0.38),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(
            Icons.local_hospital_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),
        const Spacer(),
        const SizedBox(width: 42),
      ],
    );
  }

  // ─── Icon badge ────────────────────────────────────────────────────────────
  Widget _buildIconBadge({required IconData icon, required Color color}) {
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        shape: BoxShape.circle,
        border: Border.all(color: color.withOpacity(0.30), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.20),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Icon(icon, color: color, size: 40),
    );
  }

  // ─── Tips section ──────────────────────────────────────────────────────────
  Widget _buildTips() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF5B6EF5).withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF5B6EF5).withOpacity(0.20),
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
                    color: Colors.white.withOpacity(0.45),
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

  // ─── Back to login link ────────────────────────────────────────────────────
  Widget _buildBackToLogin() {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.arrow_back_rounded,
            color: Colors.white.withOpacity(0.45),
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            'Back to Sign In',
            style: TextStyle(
              color: Colors.white.withOpacity(0.45),
              fontSize: 13.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Resend Timer Widget ──────────────────────────────────────────────────────
class _ResendTimer extends StatefulWidget {
  final Future<void> Function() onResend;
  const _ResendTimer({required this.onResend});

  @override
  State<_ResendTimer> createState() => _ResendTimerState();
}

class _ResendTimerState extends State<_ResendTimer> {
  int _seconds = 60;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() {
        _seconds--;
        if (_seconds <= 0) _canResend = true;
      });
      return _seconds > 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Didn't get the email? ",
          style: TextStyle(
            color: Colors.white.withOpacity(0.42),
            fontSize: 13.5,
          ),
        ),
        _canResend
            ? GestureDetector(
                onTap: () async {
                  setState(() {
                    _canResend = false;
                    _seconds = 60;
                  });
                  await widget.onResend();
                  _startTimer();
                },
                child: const Text(
                  'Resend',
                  style: TextStyle(
                    color: Color(0xFF00D4AA),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            : Text(
                'Resend in ${_seconds}s',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.30),
                  fontSize: 13.5,
                ),
              ),
      ],
    );
  }
}