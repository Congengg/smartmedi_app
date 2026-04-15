import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

// No UserProvider import here — context belongs in widgets, not services.

enum GoogleAuthStatus {
  success,       // signed in / registered OK
  cancelled,     // user dismissed the Google picker
  doctorBlocked, // doctor tried to use the patient app
  error,         // something else went wrong
}

class GoogleAuthResult {
  final GoogleAuthStatus status;
  final String? message;
  final String? name;

  const GoogleAuthResult({required this.status, this.message, this.name});
}

class GoogleAuthService {
  static final _auth        = FirebaseAuth.instance;
  static final _firestore   = FirebaseFirestore.instance;
  static final _googleSignIn = GoogleSignIn();

  // ─── Core: get Google credential ─────────────────────────────────────────
  static Future<OAuthCredential?> _getGoogleCredential() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null; // user cancelled

    final googleAuth = await googleUser.authentication;
    return GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
  }

  // ─── Sign In with Google ──────────────────────────────────────────────────
  // Returns a result — the WIDGET calls loadUser() on success.
  static Future<GoogleAuthResult> signIn() async {
    try {
      final credential = await _getGoogleCredential();
      if (credential == null) {
        return const GoogleAuthResult(status: GoogleAuthStatus.cancelled);
      }

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user!;
      final isNewUser = userCredential.additionalUserInfo?.isNewUser ?? false;

      if (isNewUser) {
        // First time → create Firestore document first, THEN return success
        final baseUsername = _generateUsername(user.displayName ?? 'user');
        final uniqueUsername = await _ensureUniqueUsername(baseUsername);

        await _firestore.collection('users').doc(user.uid).set({
          'name':      user.displayName ?? '',
          'username':  uniqueUsername,
          'email':     user.email ?? '',
          'phone':     '',
          'role':      'patient',
          'photoUrl':  user.photoURL ?? '',
          'createdAt': FieldValue.serverTimestamp(),
        });

        // ✅ No context.read here — widget calls loadUser() after this returns
        return GoogleAuthResult(
          status: GoogleAuthStatus.success,
          name: user.displayName,
        );
      } else {
        // Existing user — check their role
        final doc = await _firestore.collection('users').doc(user.uid).get();

        if (!doc.exists) {
          // Edge case: Auth account exists but Firestore doc is missing
          final baseUsername = _generateUsername(user.displayName ?? 'user');
          final uniqueUsername = await _ensureUniqueUsername(baseUsername);

          await _firestore.collection('users').doc(user.uid).set({
            'name':      user.displayName ?? '',
            'username':  uniqueUsername,
            'email':     user.email ?? '',
            'phone':     '',
            'role':      'patient',
            'photoUrl':  user.photoURL ?? '',
            'createdAt': FieldValue.serverTimestamp(),
          });
        } else {
          final role = doc.data()?['role'] ?? '';
          if (role == 'doctor') {
            await _auth.signOut();
            await _googleSignIn.signOut();
            return const GoogleAuthResult(
              status: GoogleAuthStatus.doctorBlocked,
              message:
                  'Doctor accounts must use the SmartMedi Web Portal to log in.',
            );
          }
        }

        return GoogleAuthResult(
          status: GoogleAuthStatus.success,
          name: user.displayName,
        );
      }
    } on FirebaseAuthException catch (e) {
      return GoogleAuthResult(
        status: GoogleAuthStatus.error,
        message: _friendlyError(e.code),
      );
    } catch (e) {
      return GoogleAuthResult(
        status: GoogleAuthStatus.error,
        message: 'Google sign-in failed. Please try again.',
      );
    }
  }

  // ─── Sign Up with Google ──────────────────────────────────────────────────
  static Future<GoogleAuthResult> signUp() async => signIn();

  // ─── Sign out ─────────────────────────────────────────────────────────────
  static Future<void> signOut() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────
  static String _generateUsername(String displayName) {
    final cleaned = displayName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final base = cleaned.substring(0, cleaned.length.clamp(0, 12));
    return base.isEmpty ? 'user' : base;
  }

  static Future<String> _ensureUniqueUsername(String base) async {
    var candidate = base;
    while (true) {
      final query = await _firestore
          .collection('users')
          .where('username', isEqualTo: candidate)
          .limit(1)
          .get();
      if (query.docs.isEmpty) return candidate;
      final suffix = DateTime.now().millisecondsSinceEpoch % 1000;
      candidate = '$base$suffix';
    }
  }

  static String _friendlyError(String code) {
    switch (code) {
      case 'account-exists-with-different-credential':
        return 'This email is already registered with a different sign-in method.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'network-request-failed':
        return 'No internet connection. Check your network.';
      default:
        return 'Google sign-in failed. Please try again.';
    }
  }
}