import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

/// Thin wrapper around Supabase Auth, mirroring the SupabaseService /
/// PlayerService pattern used elsewhere in the app. Screens and providers
/// never touch `Supabase.instance.client.auth` directly — they go through
/// this so there's one place to swap auth providers later if ever needed.
class AuthService {
  User? get currentUser =>
      SupabaseService.isReady ? SupabaseService.client.auth.currentUser : null;

  Session? get currentSession =>
      SupabaseService.isReady ? SupabaseService.client.auth.currentSession : null;

  /// Fires on sign-in, sign-out, and token refresh. Only valid to listen to
  /// when Supabase is actually configured — callers must check
  /// SupabaseService.isReady first.
  Stream<AuthState> get onAuthStateChange =>
      SupabaseService.client.auth.onAuthStateChange;

  Future<void> signUp({required String email, required String password}) async {
    if (!SupabaseService.isReady) {
      throw StateError('Supabase not configured — see .env.example');
    }
    await SupabaseService.client.auth.signUp(email: email, password: password);
  }

  Future<void> signIn({required String email, required String password}) async {
    if (!SupabaseService.isReady) {
      throw StateError('Supabase not configured — see .env.example');
    }
    await SupabaseService.client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    if (!SupabaseService.isReady) return;
    await SupabaseService.client.auth.signOut();
  }

  Future<void> sendPasswordReset(String email) async {
    if (!SupabaseService.isReady) {
      throw StateError('Supabase not configured — see .env.example');
    }
    await SupabaseService.client.auth.resetPasswordForEmail(email);
  }

  /// Re-sends the confirmation link Supabase already sent at sign-up time.
  /// Supabase itself rate-limits this (60s cooldown per project default),
  /// so no separate throttling is needed here — a resend spammed faster
  /// than that just surfaces Supabase's own AuthException.
  Future<void> resendConfirmationEmail(String email) async {
    if (!SupabaseService.isReady) {
      throw StateError('Supabase not configured — see .env.example');
    }
    await SupabaseService.client.auth.resend(type: OtpType.signup, email: email);
  }

  /// Pulls the current user fresh from Supabase rather than trusting the
  /// locally cached copy — used after someone taps the confirmation link
  /// in another tab/app and comes back to tap "I've verified" here, since
  /// the cached `currentUser` won't reflect `email_confirmed_at` changing
  /// server-side until something explicitly re-fetches it.
  Future<void> refreshUser() async {
    if (!SupabaseService.isReady) return;
    await SupabaseService.client.auth.refreshSession();
  }

  // ── TOTP MFA (2FA) — https://supabase.com/docs/guides/auth/auth-mfa/totp ──

  Future<AuthMFAEnrollResponse> enrollMfa() {
    return SupabaseService.client.auth.mfa.enroll(
      factorType: FactorType.totp,
      friendlyName: 'FUSKAMO',
    );
  }

  Future<void> unenrollMfa(String factorId) {
    return SupabaseService.client.auth.mfa.unenroll(factorId);
  }

  /// Verified TOTP factors only — an in-progress, never-completed
  /// enrollment doesn't count as "2FA is on" (Supabase auto-expires those
  /// after ~5 minutes anyway).
  Future<Factor?> getVerifiedTotpFactor() async {
    final factors = await SupabaseService.client.auth.mfa.listFactors();
    return factors.totp.where((f) => f.status == FactorStatus.verified).firstOrNull;
  }

  /// Any lingering unverified TOTP enrollment — cleaned up before starting
  /// a new one so a user who backed out mid-setup isn't stuck.
  Future<Factor?> getUnverifiedTotpFactor() async {
    final factors = await SupabaseService.client.auth.mfa.listFactors();
    return factors.totp.where((f) => f.status == FactorStatus.unverified).firstOrNull;
  }

  /// Completes either an enrollment or a post-sign-in challenge — same
  /// call, same 6-digit code check, Supabase treats them identically.
  Future<AuthMFAVerifyResponse> challengeAndVerifyMfa({
    required String factorId,
    required String code,
  }) {
    return SupabaseService.client.auth.mfa.challengeAndVerify(factorId: factorId, code: code);
  }

  /// aal1 = password only. aal2 = password + a verified second factor.
  /// nextLevel > currentLevel right after signInWithPassword means this
  /// account has 2FA on and a challenge is required before treating the
  /// session as fully authenticated.
  AuthMFAGetAuthenticatorAssuranceLevelResponse getAssuranceLevel() {
    return SupabaseService.client.auth.mfa.getAuthenticatorAssuranceLevel();
  }
}
