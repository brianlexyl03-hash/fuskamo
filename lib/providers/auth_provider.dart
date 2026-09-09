import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../notifications/push_notification_service.dart';
import '../repositories/auth_repository.dart';
import '../services/supabase_service.dart';
import '../repositories/messaging_repository.dart';

enum AuthStatus { unknown, signedOut, mfaRequired, signedIn }

/// Drives the Profile screen and anything else that needs to know whether
/// someone is logged in. Registered in app.dart alongside NavProvider /
/// PlayerProvider / ScoutProvider.
///
/// mfaRequired sits between signedOut and signedIn: Supabase creates a real
/// session (aal1) the instant signInWithPassword succeeds, even for an
/// account with 2FA on — the onAuthStateChange listener fires with a
/// non-null session immediately. Without the _awaitingMfa guard below,
/// that would flip status straight to signedIn and skip the 2FA prompt
/// entirely, which would make enrolling in 2FA pointless.
class AuthProvider extends ChangeNotifier {
  final AuthRepository _repo = AuthRepository();
  StreamSubscription<AuthState>? _sub;
  bool _awaitingMfa = false;

  AuthStatus _status = AuthStatus.unknown;
  bool _busy = false;
  String? _error;
  String? _pendingMfaFactorId;

  AuthProvider() {
    if (!SupabaseService.isReady) {
      // Supabase isn't configured (see README) — treat as permanently
      // signed out rather than crashing on auth calls.
      _status = AuthStatus.signedOut;
      return;
    }

    _status = _repo.currentUser != null ? AuthStatus.signedIn : AuthStatus.signedOut;
    _sub = _repo.onAuthStateChange.listen((state) {
      if (state.session == null) {
        _status = AuthStatus.signedOut;
        _awaitingMfa = false;
        _pendingMfaFactorId = null;
        notifyListeners();
        return;
      }

      if (_awaitingMfa) {
        // Session exists (aal1) but we're deliberately holding at
        // mfaRequired until the challenge completes — see _submit below.
        return;
      }

      _status = AuthStatus.signedIn;
      notifyListeners();
      _ensureMessagingProfile();
      // Attach this device's push token to the now-known user id so
      // notifications can be targeted — see push_notification_service.dart.
      PushNotificationService.instance.registerTokenForCurrentUser();
    });
  }

  AuthStatus get status => _status;
  bool get busy => _busy;
  String? get error => _error;
  User? get user => _repo.currentUser;
  bool get isConfigured => SupabaseService.isReady;
  String? get pendingMfaFactorId => _pendingMfaFactorId;

  /// Supabase sets email_confirmed_at only after the confirmation link is
  /// clicked. Whether an unconfirmed account even reaches `signedIn` at
  /// all depends on the Supabase project's "Confirm email" setting — if
  /// it's off, signUp hands back an active session immediately. Checking
  /// this explicitly, rather than assuming the project setting is on, is
  /// what actually gates the account area in profile_screen.dart.
  bool get isEmailVerified => user?.emailConfirmedAt != null;

  Future<String?> resendVerificationEmail() {
    final email = user?.email;
    if (email == null) return Future.value('No email on this account.');
    return _repo.resendConfirmationEmail(email);
  }

  /// Re-fetches the user from Supabase and notifies listeners so
  /// isEmailVerified reflects a just-clicked confirmation link without
  /// requiring a full sign-out/sign-in.
  Future<String?> refreshVerificationStatus() async {
    final err = await _repo.refreshUser();
    notifyListeners();
    return err;
  }

  Future<bool> signIn({required String email, required String password}) async {
    _busy = true;
    _error = null;
    notifyListeners();

    final err = await _repo.signIn(email: email, password: password);
    if (err != null) {
      _busy = false;
      _error = err;
      notifyListeners();
      return false;
    }

    // Signed in at aal1 — check whether this account has 2FA on.
    if (_repo.needsMfaChallenge()) {
      final factor = await _repo.getVerifiedTotpFactor();
      if (factor != null) {
        _awaitingMfa = true;
        _pendingMfaFactorId = factor.id;
        _status = AuthStatus.mfaRequired;
        _busy = false;
        notifyListeners();
        return true;
      }
    }

    _status = AuthStatus.signedIn;
    _busy = false;
    notifyListeners();
    _ensureMessagingProfile();
    PushNotificationService.instance.registerTokenForCurrentUser();
    return true;
  }

  /// Called from MfaChallengeScreen with the 6-digit code. Returns null on
  /// success, or an error string.
  Future<String?> submitMfaCode(String code) async {
    final factorId = _pendingMfaFactorId;
    if (factorId == null) return 'No pending 2FA challenge.';
    _busy = true;
    notifyListeners();
    final err = await _repo.completeMfaChallenge(factorId: factorId, code: code);
    _busy = false;
    if (err == null) {
      _awaitingMfa = false;
      _pendingMfaFactorId = null;
      _status = AuthStatus.signedIn;
      _ensureMessagingProfile();
      PushNotificationService.instance.registerTokenForCurrentUser();
    }
    notifyListeners();
    return err;
  }

  Future<bool> signUp({required String email, required String password}) =>
      _submit(() => _repo.signUp(email: email, password: password));

  Future<bool> _submit(Future<String?> Function() action) async {
    _busy = true;
    _error = null;
    notifyListeners();
    final err = await action();
    _busy = false;
    _error = err;
    notifyListeners();
    return err == null;
  }

  Future<void> _ensureMessagingProfile() async {
    final u = user;
    if (u == null) return;
    final m = u.userMetadata ?? <String, dynamic>{};
    try {
      await MessagingRepository().ensureMyProfile(
        displayName: m['display_name']?.toString(),
        username: m['username']?.toString(),
        bio: m['bio']?.toString(),
        avatarUrl: m['avatar_url']?.toString(),
        website: m['website']?.toString(),
        instagram: m['instagram']?.toString(),
        xHandle: m['x']?.toString(),
        tiktok: m['tiktok']?.toString(),
        snapchat: m['snapchat']?.toString(),
        bluesky: m['bluesky']?.toString(),
        role: m['role']?.toString() ?? 'player',
      );
    } catch (_) {
      // Messaging must never prevent a successful login.
    }
  }

  Future<void> signOut() async {
    _awaitingMfa = false;
    _pendingMfaFactorId = null;
    await PushNotificationService.instance.unregisterToken();
    await _repo.signOut();
  }

  Future<String?> sendPasswordReset(String email) => _repo.sendPasswordReset(email);

  // ── TOTP MFA management (Profile → Two-factor authentication) ──

  Future<({String? factorId, String? qrData, String? secret, String? error})> beginMfaEnrollment() =>
      _repo.beginMfaEnrollment();

  Future<String?> completeMfaEnrollment({required String factorId, required String code}) =>
      _repo.completeMfaChallenge(factorId: factorId, code: code);

  Future<Factor?> getVerifiedTotpFactor() => _repo.getVerifiedTotpFactor();

  Future<String?> disableMfa(String factorId) => _repo.disableMfa(factorId);

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
