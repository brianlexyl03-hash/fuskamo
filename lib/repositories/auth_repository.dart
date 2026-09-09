import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';

/// Sits between AuthProvider and AuthService, same role PlayerRepository
/// plays for PlayerService: translates raw exceptions into plain strings
/// the UI can show directly, so screens never catch Supabase-specific
/// exception types themselves.
class AuthRepository {
  final AuthService _service = AuthService();

  User? get currentUser => _service.currentUser;
  Session? get currentSession => _service.currentSession;
  Stream<AuthState> get onAuthStateChange => _service.onAuthStateChange;

  /// Returns null on success, or a user-facing error message on failure.
  Future<String?> signUp({required String email, required String password}) async {
    try {
      await _service.signUp(email: email, password: password);
      return null;
    } on AuthException catch (e) {
      return e.message;
    } on StateError catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not create account. Check your connection and try again.';
    }
  }

  Future<String?> signIn({required String email, required String password}) async {
    try {
      await _service.signIn(email: email, password: password);
      return null;
    } on AuthException catch (e) {
      return e.message;
    } on StateError catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not sign in. Check your connection and try again.';
    }
  }

  Future<void> signOut() => _service.signOut();

  Future<String?> sendPasswordReset(String email) async {
    try {
      await _service.sendPasswordReset(email);
      return null;
    } on AuthException catch (e) {
      return e.message;
    } on StateError catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not send reset email. Try again shortly.';
    }
  }

  Future<String?> resendConfirmationEmail(String email) async {
    try {
      await _service.resendConfirmationEmail(email);
      return null;
    } on AuthException catch (e) {
      return e.message;
    } on StateError catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not resend the confirmation email. Try again shortly.';
    }
  }

  Future<String?> refreshUser() async {
    try {
      await _service.refreshUser();
      return null;
    } on AuthException catch (e) {
      return e.message;
    } on StateError catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not check verification status. Try again.';
    }
  }

  // ── TOTP MFA ──

  /// Returns (factorId, qrData, secret) on success, or (null, null, error)
  /// on failure — cleans up any stale unverified enrollment first so a
  /// user who backed out mid-setup last time isn't stuck.
  Future<({String? factorId, String? qrData, String? secret, String? error})> beginMfaEnrollment() async {
    try {
      final stale = await _service.getUnverifiedTotpFactor();
      if (stale != null) await _service.unenrollMfa(stale.id);

      final res = await _service.enrollMfa();
      return (factorId: res.id, qrData: res.totp?.qrCode, secret: res.totp?.secret, error: null);
    } on AuthException catch (e) {
      return (factorId: null, qrData: null, secret: null, error: e.message);
    } catch (_) {
      return (factorId: null, qrData: null, secret: null, error: 'Could not start 2FA setup. Try again.');
    }
  }

  /// Returns null on success (enrollment or sign-in challenge, same call).
  Future<String?> completeMfaChallenge({required String factorId, required String code}) async {
    try {
      await _service.challengeAndVerifyMfa(factorId: factorId, code: code);
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (_) {
      return 'Incorrect code, or it expired. Try the latest code from your authenticator app.';
    }
  }

  Future<String?> disableMfa(String factorId) async {
    try {
      await _service.unenrollMfa(factorId);
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not disable 2FA. Try again.';
    }
  }

  Future<Factor?> getVerifiedTotpFactor() => _service.getVerifiedTotpFactor();

  /// True right after signInWithPassword when the account has a verified
  /// TOTP factor and the session hasn't been upgraded to aal2 yet.
  bool needsMfaChallenge() {
    final levels = _service.getAssuranceLevel();
    return levels.nextLevel == AuthenticatorAssuranceLevels.aal2 &&
        levels.currentLevel != AuthenticatorAssuranceLevels.aal2;
  }
}
