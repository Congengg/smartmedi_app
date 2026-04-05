import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../widgets/common/blob_painter.dart';
import '../../widgets/common/gradient_button.dart';
import '../../widgets/common/app_input_field.dart';
import '../../widgets/common/top_bar.dart';
import 'login.dart';

enum UserRole { patient, doctor }

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

  UserRole _selectedRole = UserRole.patient;

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
      if (mounted) _fadeCtrl.forward();
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

  void _validate() {
    setState(() {
      _nameError = _nameCtrl.text.trim().isEmpty
          ? 'Full name is required'
          : (_nameCtrl.text.trim().length < 2 ? 'Name too short' : null);

      _emailError = _emailCtrl.text.trim().isEmpty
          ? 'Email is required'
          : (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(_emailCtrl.text.trim())
                ? 'Enter a valid email'
                : null);

      _phoneError =
          !RegExp(r'^(\+?60|0)[0-9]{8,10}$').hasMatch(_phoneCtrl.text.trim())
          ? 'Enter a valid Malaysian phone number'
          : null;

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
    try {
      // TODO: Firebase Auth
      // final credential = await FirebaseAuth.instance
      //     .createUserWithEmailAndPassword(
      //   email: _emailCtrl.text.trim(),
      //   password: _passCtrl.text,
      // );
      // await FirebaseFirestore.instance
      //     .collection('users')
      //     .doc(credential.user!.uid)
      //     .set({
      //   'name': _nameCtrl.text.trim(),
      //   'email': _emailCtrl.text.trim(),
      //   'phone': _phoneCtrl.text.trim(),
      //   'role': _selectedRole.name,
      //   'createdAt': FieldValue.serverTimestamp(),
      // });
      // await credential.user!.updateDisplayName(_nameCtrl.text.trim());
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );
      }
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
                  blobs: AppBlobs.register,
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
                          const TopBar(),
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
                              color: Colors.white.withValues(alpha: 0.45),
                              fontSize: 13.5,
                            ),
                          ),
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
          _buildRoleSelector(),
          const SizedBox(height: 24),

          AppInputField(
            controller: _nameCtrl,
            label: 'Full name',
            icon: Icons.person_outline_rounded,
            keyboardType: TextInputType.name,
            textCapitalization: TextCapitalization.words,
            hintText: 'e.g. Ahmad bin Ali',
            errorText: _nameError,
            onChanged: (_) => setState(() => _nameError = null),
          ),
          const SizedBox(height: 14),

          AppInputField(
            controller: _emailCtrl,
            label: 'Email address',
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            errorText: _emailError,
            onChanged: (_) => setState(() => _emailError = null),
          ),
          const SizedBox(height: 14),

          AppInputField(
            controller: _phoneCtrl,
            label: 'Phone number',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            hintText: 'e.g. 011-12345678',
            errorText: _phoneError,
            onChanged: (_) => setState(() => _phoneError = null),
          ),
          const SizedBox(height: 14),

          AppInputField(
            controller: _passCtrl,
            label: 'Password',
            icon: Icons.lock_outline_rounded,
            obscureText: _obscurePass,
            errorText: _passError,
            onChanged: (_) => setState(() => _passError = null),
            suffix: IconButton(
              onPressed: () => setState(() => _obscurePass = !_obscurePass),
              icon: Icon(
                _obscurePass
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: Colors.white.withValues(alpha: 0.4),
                size: 20,
              ),
            ),
          ),
          const SizedBox(height: 14),

          AppInputField(
            controller: _confirmPassCtrl,
            label: 'Confirm password',
            icon: Icons.lock_outline_rounded,
            obscureText: _obscureConfirm,
            errorText: _confirmPassError,
            onChanged: (_) => setState(() => _confirmPassError = null),
            suffix: IconButton(
              onPressed: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
              icon: Icon(
                _obscureConfirm
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: Colors.white.withValues(alpha: 0.4),
                size: 20,
              ),
            ),
          ),
          const SizedBox(height: 20),

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

          GradientButton(
            label: 'Create Account',
            loading: _loading,
            onPressed: _validate,
          ),
        ],
      ),
    );
  }

  Widget _buildRoleSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'I am a...',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.55),
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
              role: UserRole.patient,
            ),
            const SizedBox(width: 12),
            _roleChip(
              label: 'Doctor',
              icon: Icons.medical_services_outlined,
              role: UserRole.doctor,
            ),
          ],
        ),
      ],
    );
  }

  Widget _roleChip({
    required String label,
    required IconData icon,
    required UserRole role,
  }) {
    final selected = _selectedRole == role;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedRole = role),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF00D4AA).withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? const Color(0xFF00D4AA)
                  : Colors.white.withValues(alpha: 0.10),
              width: selected ? 1.6 : 1.0,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: selected
                    ? const Color(0xFF00D4AA)
                    : Colors.white.withValues(alpha: 0.40),
                size: 22,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected
                      ? const Color(0xFF00D4AA)
                      : Colors.white.withValues(alpha: 0.50),
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
                    : Colors.white.withValues(alpha: 0.25),
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
                  color: Colors.white.withValues(alpha: 0.50),
                  fontSize: 13,
                  height: 1.5,
                ),
                children: [
                  const TextSpan(text: 'I agree to the '),
                  TextSpan(
                    text: 'Terms of Service',
                    style: const TextStyle(
                      color: Color(0xFF00D4AA),
                      fontWeight: FontWeight.w500,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        // TODO: Navigator.push to TermsPage
                      },
                  ),
                  const TextSpan(text: ' and '),
                  TextSpan(
                    text: 'Privacy Policy',
                    style: const TextStyle(
                      color: Color(0xFF00D4AA),
                      fontWeight: FontWeight.w500,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        // TODO: Navigator.push to PrivacyPage
                      },
                  ),
                ],
              ),
            ),
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
            'or sign up with',
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

  Widget _buildLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Already have an account? ',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
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
