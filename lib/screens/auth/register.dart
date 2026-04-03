import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'login.dart';

// ─── Animated blob background painter ────────────────────────────────────────
class _BlobPainter extends CustomPainter {
  final double t;
  _BlobPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Blob 1 — indigo (shifted positions vs login for variety)
    paint.color = const Color(0xFF5B6EF5).withOpacity(0.16);
    final c1 = Offset(
      size.width * (0.85 + 0.07 * math.sin(t)),
      size.height * (0.12 + 0.06 * math.cos(t * 0.8)),
    );
    canvas.drawCircle(c1, size.width * 0.40, paint);

    // Blob 2 — teal
    paint.color = const Color(0xFF00D4AA).withOpacity(0.15);
    final c2 = Offset(
      size.width * (0.10 + 0.07 * math.cos(t * 0.9)),
      size.height * (0.50 + 0.07 * math.sin(t * 1.1)),
    );
    canvas.drawCircle(c2, size.width * 0.38, paint);

    // Blob 3 — rose
    paint.color = const Color(0xFFE040A0).withOpacity(0.09);
    final c3 = Offset(
      size.width * (0.55 + 0.06 * math.cos(t * 1.2)),
      size.height * (0.88 + 0.04 * math.sin(t * 0.9)),
    );
    canvas.drawCircle(c3, size.width * 0.34, paint);
  }

  @override
  bool shouldRepaint(_BlobPainter old) => old.t != t;
}

// ─── Register Page ────────────────────────────────────────────────────────────
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage>
    with TickerProviderStateMixin {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  bool _agreeToTerms = false;

  String? _nameError;
  String? _emailError;
  String? _phoneError;
  String? _passError;
  String? _confirmPassError;
  String? _termsError;

  // Role selector: 'patient' or 'doctor'
  String _selectedRole = 'patient';

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

    Future.delayed(const Duration(milliseconds: 150), () {
      _fadeCtrl.forward();
    });
  }

  @override
  void dispose() {
    _blobCtrl.dispose();
    _fadeCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  // ─── Validation ─────────────────────────────────────────────────────────────
  void _validate() {
    setState(() {
      _nameError = _nameCtrl.text.trim().isEmpty
          ? 'Full name is required'
          : (_nameCtrl.text.trim().length < 2 ? 'Name too short' : null);

      _emailError = _emailCtrl.text.isEmpty
          ? 'Email is required'
          : (!_emailCtrl.text.contains('@') ? 'Enter a valid email' : null);

      _phoneError = _phoneCtrl.text.isEmpty
          ? 'Phone number is required'
          : (_phoneCtrl.text.length < 8 ? 'Enter a valid phone number' : null);

      _passError = _passCtrl.text.isEmpty
          ? 'Password is required'
          : (_passCtrl.text.length < 6 ? 'At least 6 characters' : null);

      _confirmPassError = _confirmPassCtrl.text.isEmpty
          ? 'Please confirm your password'
          : (_confirmPassCtrl.text != _passCtrl.text
                ? 'Passwords do not match'
                : null);

      _termsError = !_agreeToTerms ? 'You must agree to the terms' : null;
    });

    if (_nameError == null &&
        _emailError == null &&
        _phoneError == null &&
        _passError == null &&
        _confirmPassError == null &&
        _termsError == null) {
      _submit();
    }
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _loading = false);
    // TODO: Replace with Firebase Auth
    // await FirebaseAuth.instance.createUserWithEmailAndPassword(
    //   email: _emailCtrl.text.trim(),
    //   password: _passCtrl.text,
    // );
    // Then save extra fields (name, phone, role) to Firestore:
    // await FirebaseFirestore.instance.collection('users').doc(uid).set({
    //   'name': _nameCtrl.text.trim(),
    //   'phone': _phoneCtrl.text.trim(),
    //   'role': _selectedRole,
    //   'createdAt': FieldValue.serverTimestamp(),
    // });
  }

  // ─── Input decoration ────────────────────────────────────────────────────────
  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffix,
    String? error,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 14),
      labelStyle: TextStyle(
        color: Colors.white.withOpacity(0.5),
        fontSize: 14,
        letterSpacing: 0.3,
      ),
      prefixIcon: Icon(icon, color: const Color(0xFF00D4AA), size: 20),
      suffixIcon: suffix,
      errorText: error,
      errorStyle: const TextStyle(color: Color(0xFFFF6B8A), fontSize: 12),
      filled: true,
      fillColor: Colors.white.withOpacity(0.06),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
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

              // Scrollable content
              SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: SlideTransition(
                      position: _slideAnim,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 28),
                          _buildHeader(),
                          const SizedBox(height: 32),
                          _buildCard(),
                          const SizedBox(height: 28),
                          _buildDivider(),
                          const SizedBox(height: 20),
                          _buildGoogleButton(),
                          const SizedBox(height: 32),
                          _buildLoginLink(),
                          const SizedBox(height: 28),
                        ],
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

  // ─── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Column(
      children: [
        // Back button + logo row
        Row(
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
            const SizedBox(width: 42), // balance the back button
          ],
        ),
        const SizedBox(height: 20),
        const Text(
          'Create Account',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Join SmartMedi and take control of your health',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withOpacity(0.45),
            fontSize: 13.5,
          ),
        ),
      ],
    );
  }

  // ─── Main card ─────────────────────────────────────────────────────────────
  Widget _buildCard() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.09), width: 1.2),
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
          // ── Role selector ────────────────────────────────────────────────
          _buildRoleSelector(),
          const SizedBox(height: 24),

          // ── Full name ────────────────────────────────────────────────────
          TextFormField(
            controller: _nameCtrl,
            keyboardType: TextInputType.name,
            textCapitalization: TextCapitalization.words,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: _inputDecoration(
              label: 'Full name',
              icon: Icons.person_outline_rounded,
              error: _nameError,
              hint: 'e.g. Ahmad bin Ali',
            ),
            onChanged: (_) => setState(() => _nameError = null),
          ),
          const SizedBox(height: 14),

          // ── Email ────────────────────────────────────────────────────────
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: _inputDecoration(
              label: 'Email address',
              icon: Icons.mail_outline_rounded,
              error: _emailError,
            ),
            onChanged: (_) => setState(() => _emailError = null),
          ),
          const SizedBox(height: 14),

          // ── Phone ────────────────────────────────────────────────────────
          TextFormField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: _inputDecoration(
              label: 'Phone number',
              icon: Icons.phone_outlined,
              error: _phoneError,
              hint: 'e.g. 011-12345678',
            ),
            onChanged: (_) => setState(() => _phoneError = null),
          ),
          const SizedBox(height: 14),

          // ── Password ─────────────────────────────────────────────────────
          TextFormField(
            controller: _passCtrl,
            obscureText: _obscurePass,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: _inputDecoration(
              label: 'Password',
              icon: Icons.lock_outline_rounded,
              error: _passError,
              suffix: IconButton(
                onPressed: () => setState(() => _obscurePass = !_obscurePass),
                icon: Icon(
                  _obscurePass
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.white.withOpacity(0.4),
                  size: 20,
                ),
              ),
            ),
            onChanged: (_) => setState(() => _passError = null),
          ),
          const SizedBox(height: 14),

          // ── Confirm password ─────────────────────────────────────────────
          TextFormField(
            controller: _confirmPassCtrl,
            obscureText: _obscureConfirm,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: _inputDecoration(
              label: 'Confirm password',
              icon: Icons.lock_outline_rounded,
              error: _confirmPassError,
              suffix: IconButton(
                onPressed: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
                icon: Icon(
                  _obscureConfirm
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.white.withOpacity(0.4),
                  size: 20,
                ),
              ),
            ),
            onChanged: (_) => setState(() => _confirmPassError = null),
          ),
          const SizedBox(height: 20),

          // ── Terms checkbox ───────────────────────────────────────────────
          _buildTermsCheckbox(),
          if (_termsError != null) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                _termsError!,
                style: const TextStyle(color: Color(0xFFFF6B8A), fontSize: 12),
              ),
            ),
          ],
          const SizedBox(height: 24),

          // ── Sign Up button ───────────────────────────────────────────────
          _buildSignUpButton(),
        ],
      ),
    );
  }

  // ─── Role selector ─────────────────────────────────────────────────────────
  Widget _buildRoleSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'I am a...',
          style: TextStyle(
            color: Colors.white.withOpacity(0.55),
            fontSize: 13,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _roleChip(
              label: 'Patient',
              icon: Icons.personal_injury_outlined,
              value: 'patient',
            ),
            const SizedBox(width: 12),
            _roleChip(
              label: 'Doctor',
              icon: Icons.medical_services_outlined,
              value: 'doctor',
            ),
          ],
        ),
      ],
    );
  }

  Widget _roleChip({
    required String label,
    required IconData icon,
    required String value,
  }) {
    final selected = _selectedRole == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedRole = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF00D4AA).withOpacity(0.15)
                : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? const Color(0xFF00D4AA)
                  : Colors.white.withOpacity(0.10),
              width: selected ? 1.6 : 1.0,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: selected
                    ? const Color(0xFF00D4AA)
                    : Colors.white.withOpacity(0.40),
                size: 22,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected
                      ? const Color(0xFF00D4AA)
                      : Colors.white.withOpacity(0.50),
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Terms checkbox ─────────────────────────────────────────────────────────
  Widget _buildTermsCheckbox() {
    return GestureDetector(
      onTap: () => setState(() {
        _agreeToTerms = !_agreeToTerms;
        if (_agreeToTerms) _termsError = null;
      }),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: _agreeToTerms
                  ? const Color(0xFF00D4AA)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: _agreeToTerms
                    ? const Color(0xFF00D4AA)
                    : Colors.white.withOpacity(0.25),
                width: 1.5,
              ),
            ),
            child: _agreeToTerms
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  color: Colors.white.withOpacity(0.50),
                  fontSize: 13,
                  height: 1.5,
                ),
                children: const [
                  TextSpan(text: 'I agree to the '),
                  TextSpan(
                    text: 'Terms of Service',
                    style: TextStyle(
                      color: Color(0xFF00D4AA),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  TextSpan(text: ' and '),
                  TextSpan(
                    text: 'Privacy Policy',
                    style: TextStyle(
                      color: Color(0xFF00D4AA),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Sign Up button ─────────────────────────────────────────────────────────
  Widget _buildSignUpButton() {
    return SizedBox(
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
                    color: const Color(0xFF00D4AA).withOpacity(0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _validate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Create Account',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
    );
  }

  // ─── Divider ───────────────────────────────────────────────────────────────
  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(
          child: Divider(color: Colors.white.withOpacity(0.12), thickness: 1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'or sign up with',
            style: TextStyle(
              color: Colors.white.withOpacity(0.35),
              fontSize: 12.5,
              letterSpacing: 0.2,
            ),
          ),
        ),
        Expanded(
          child: Divider(color: Colors.white.withOpacity(0.12), thickness: 1),
        ),
      ],
    );
  }

  // ─── Google button ─────────────────────────────────────────────────────────
  Widget _buildGoogleButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: () {
          // TODO: Google Sign-Up
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
          side: BorderSide(color: Colors.white.withOpacity(0.15), width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          backgroundColor: Colors.white.withOpacity(0.05),
        ),
      ),
    );
  }

  // ─── Login link ─────────────────────────────────────────────────────────────
  Widget _buildLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Already have an account? ',
          style: TextStyle(
            color: Colors.white.withOpacity(0.45),
            fontSize: 13.5,
          ),
        ),
        GestureDetector(
          onTap: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginPage()),
          ),
          child: const Text(
            'Sign In',
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
