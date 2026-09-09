import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Factor;
import '../constants/app_colors.dart';
import '../providers/auth_provider.dart';
import '../providers/saved_players_provider.dart';
import '../models/player_model.dart';
import '../repositories/player_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/player_card.dart';
import 'mfa_challenge_screen.dart';
import 'mfa_setup_screen.dart';
import 'notification_preferences_screen.dart';
import 'discovery_feed_screen.dart';
import 'scout_apply_screen.dart';
import 'scout_preferences_screen.dart';
import 'account_settings_screen.dart';
import 'messages_screen.dart';
import 'creator_analytics_screen.dart';
import 'moderation_center_screen.dart';
import 'achievements_screen.dart';
import 'verification_center_screen.dart';
import 'scoreboard_screen.dart';
import 'security_settings_screen.dart';

/// Real accounts screen backed by Supabase Auth via AuthProvider.
/// Signed out: email/password sign-in or sign-up.
/// Signed in: account summary + sign out.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (!auth.isConfigured) {
          return const SafeArea(
            child: Center(
              child: EmptyState(
                icon: '👤',
                title: 'Profile unavailable',
                description: 'Supabase isn\'t configured yet — add SUPABASE_URL and '
                    'SUPABASE_ANON_KEY to .env to enable accounts.',
              ),
            ),
          );
        }

        if (auth.status == AuthStatus.mfaRequired) {
          return const SafeArea(child: MfaChallengeScreen());
        }

        if (auth.status == AuthStatus.signedIn && !auth.isEmailVerified) {
          return _EmailVerificationGate(auth: auth);
        }

        if (auth.status == AuthStatus.signedIn) {
          return _SignedInView(auth: auth);
        }

        return _AuthForm(auth: auth);
      },
    );
  }
}

/// Shown instead of the account area for a signed-in-but-unconfirmed
/// account. Previously the only feedback after signing up was a snackbar
/// that disappeared in a few seconds — nothing persistent told a returning
/// user *why* their account looked empty, and there was no way to resend
/// the email or tell the app "I've clicked it now, check again."
class _EmailVerificationGate extends StatefulWidget {
  final AuthProvider auth;
  const _EmailVerificationGate({required this.auth});

  @override
  State<_EmailVerificationGate> createState() => _EmailVerificationGateState();
}

class _EmailVerificationGateState extends State<_EmailVerificationGate> {
  bool _busy = false;
  String? _message;
  DateTime? _lastResendAt;

  bool get _canResend =>
      _lastResendAt == null || DateTime.now().difference(_lastResendAt!) > const Duration(seconds: 60);

  Future<void> _resend() async {
    if (!_canResend) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    final err = await widget.auth.resendVerificationEmail();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _lastResendAt = DateTime.now();
      _message = err ?? 'Confirmation email sent — check your inbox and spam folder.';
    });
  }

  Future<void> _checkAgain() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    final err = await widget.auth.refreshVerificationStatus();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = err ?? (widget.auth.isEmailVerified ? null : 'Still not confirmed — click the link in the email first.');
    });
  }

  @override
  Widget build(BuildContext context) {
    final email = widget.auth.user?.email ?? 'your email';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.mark_email_unread_outlined, color: AppColors.green, size: 56),
            const SizedBox(height: 20),
            Text('CONFIRM YOUR EMAIL', style: AppTheme.display(24), textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Text(
              'We sent a confirmation link to $email. Verify it to save players, '
              'track submissions, and apply as a scout.',
              style: AppTheme.body(13, color: AppColors.sub),
              textAlign: TextAlign.center,
            ),
            if (_message != null) ...[
              const SizedBox(height: 16),
              Text(_message!, style: AppTheme.body(12, color: AppColors.green), textAlign: TextAlign.center),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _busy ? null : _checkAgain,
              child: _busy
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.black),
                    )
                  : const Text("I've verified — check again"),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: (_busy || !_canResend) ? null : _resend,
              child: Text(
                _canResend ? 'Resend confirmation email' : 'Resend available again shortly',
                style: AppTheme.body(13, color: AppColors.sub),
              ),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => widget.auth.signOut(),
              child: Text('Sign out', style: AppTheme.body(13, color: AppColors.red)),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignedInView extends StatefulWidget {
  final AuthProvider auth;
  const _SignedInView({required this.auth});

  @override
  State<_SignedInView> createState() => _SignedInViewState();
}

class _SignedInViewState extends State<_SignedInView> {
  final _playerRepo = PlayerRepository();
  late Future<List<Player>> _savedFuture;
  late Future<List<Player>> _mySubmissionsFuture;

  @override
  void initState() {
    super.initState();
    _savedFuture = context.read<SavedPlayersProvider>().loadFullList();
    _mySubmissionsFuture = _loadMySubmissions();
  }

  Future<List<Player>> _loadMySubmissions() {
    final userId = widget.auth.user?.id;
    if (userId == null) return Future.value([]);
    return _playerRepo.getMySubmissions(userId);
  }

  Future<void> _refresh() async {
    final saved = context.read<SavedPlayersProvider>().loadFullList();
    final mine = _loadMySubmissions();
    setState(() {
      _savedFuture = saved;
      _mySubmissionsFuture = mine;
    });
    await Future.wait([saved, mine]);
  }

  @override
  Widget build(BuildContext context) {
    final auth = widget.auth;
    final user = auth.user;
    final email = user?.email ?? '';
    final initials = email.isNotEmpty ? email[0].toUpperCase() : '?';
    final createdAt = user?.createdAt != null ? DateTime.tryParse(user!.createdAt) : null;

    // Re-fetch the saved list whenever a save/unsave happens elsewhere in
    // the app (e.g. tapping 🔖 on a feed card) — cheap since it's just a
    // small join query, and keeps this screen from showing stale data.
    context.watch<SavedPlayersProvider>();

    return SafeArea(
      child: RefreshIndicator(
        color: AppColors.green,
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(children:[Expanded(child: Text('PROFILE', style: AppTheme.display(30))), IconButton(tooltip:'Messages', onPressed:()=>Navigator.push(context, MaterialPageRoute(builder:(_)=>const MessagesScreen())), icon:const Icon(Icons.chat_bubble_outline)), IconButton(tooltip:'Account settings', onPressed:()=>Navigator.push(context, MaterialPageRoute(builder:(_)=>AccountSettingsScreen(auth:auth))), icon:const Icon(Icons.settings_outlined))]),
            const SizedBox(height: 24),
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: AppColors.card,
                    child: Text(initials, style: AppTheme.display(28, color: AppColors.green)),
                  ),
                  const SizedBox(height: 12),
                  Text(email, style: AppTheme.body(15, weight: FontWeight.w600)),
                  if (createdAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Member since ${createdAt.day}/${createdAt.month}/${createdAt.year}',
                      style: AppTheme.body(12, color: AppColors.sub),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Divider(color: AppColors.border, height: 1),
            _TwoFactorTile(auth: auth),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.notifications_none, color: AppColors.green),
              title: Text('Notification preferences', style: AppTheme.body(14)),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NotificationPreferencesScreen()),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.security_outlined, color: AppColors.green),
              title: Text('Security & active sessions', style: AppTheme.body(14)),
              subtitle: Text('Login alerts, discoverability and device sessions', style: AppTheme.body(11, color: AppColors.sub)),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SecuritySettingsScreen())),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.shield_outlined, color: AppColors.green),
              title: Text('Moderation center', style: AppTheme.body(14)),
              subtitle: Text('Authorized reviewers only', style: AppTheme.body(11, color: AppColors.sub)),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ModerationCenterScreen())),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.insights_outlined, color: AppColors.green),
              title: Text('Creator analytics', style: AppTheme.body(14)),
              subtitle: Text('Posts, reels, stories and audience performance', style: AppTheme.body(11, color: AppColors.sub)),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreatorAnalyticsScreen())),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.emoji_events_outlined, color: AppColors.green),
              title: Text('Achievements & awards', style: AppTheme.body(14)),
              subtitle: Text('Recognition is earned, never bought', style: AppTheme.body(11, color: AppColors.sub)),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AchievementsScreen())),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.verified_user_outlined, color: AppColors.green),
              title: Text('Trust & verification', style: AppTheme.body(14)),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VerificationCenterScreen())),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.leaderboard_outlined, color: AppColors.green),
              title: Text('FUSKAMO scoreboard', style: AppTheme.body(14)),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ScoreboardScreen())),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.badge_outlined, color: AppColors.green),
              title: Text('Apply as a scout', style: AppTheme.body(14)),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ScoutApplyScreen()),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.explore_outlined, color: AppColors.green),
              title: Text('Discover players (scout feed)', style: AppTheme.body(14)),
              subtitle: Text(
                'Ranked picks for verified scouts',
                style: AppTheme.body(11, color: AppColors.sub),
              ),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DiscoveryFeedScreen()),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.tune, color: AppColors.green),
              title: Text('Discovery preferences', style: AppTheme.body(14)),
              subtitle: Text(
                'Positions, countries, age range for your feed',
                style: AppTheme.body(11, color: AppColors.sub),
              ),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ScoutPreferencesScreen()),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.logout, color: AppColors.red),
              title: Text('Sign out', style: AppTheme.body(14, color: AppColors.red)),
              onTap: () => auth.signOut(),
            ),
            const SizedBox(height: 16),
            Text('MY SUBMISSIONS', style: AppTheme.display(20)),
            const SizedBox(height: 10),
            FutureBuilder<List<Player>>(
              future: _mySubmissionsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: CircularProgressIndicator(color: AppColors.green)),
                  );
                }
                final mine = snapshot.data ?? [];
                if (mine.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: EmptyState(
                      icon: '📋',
                      title: 'No submissions yet',
                      description: 'Players you submit while signed in will track their review status here.',
                    ),
                  );
                }
                return Column(children: mine.map((p) => _SubmissionTile(player: p)).toList());
              },
            ),
            const SizedBox(height: 24),
            Text('SAVED PLAYERS', style: AppTheme.display(20)),
            const SizedBox(height: 10),
            FutureBuilder<List<Player>>(
              future: _savedFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: CircularProgressIndicator(color: AppColors.green)),
                  );
                }
                final saved = snapshot.data ?? [];
                if (saved.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: EmptyState(
                      icon: '🔖',
                      title: 'No saved players yet',
                      description: 'Tap 🔖 on a player card in the feed to save them here.',
                    ),
                  );
                }
                return Column(children: saved.map((p) => PlayerCard(player: p)).toList());
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthForm extends StatefulWidget {
  final AuthProvider auth;
  const _AuthForm({required this.auth});

  @override
  State<_AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends State<_AuthForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSignUp = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    final ok = _isSignUp
        ? await widget.auth.signUp(email: email, password: password)
        : await widget.auth.signIn(email: email, password: password);

    if (ok && _isSignUp && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account created — confirm your email to finish setting up.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = widget.auth;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_isSignUp ? 'CREATE ACCOUNT' : 'SIGN IN', style: AppTheme.display(28)),
              const SizedBox(height: 4),
              Text(
                _isSignUp
                    ? 'Save players, track submissions, and get scout alerts.'
                    : 'Sign in to your FUSKAMO account.',
                style: AppTheme.body(13, color: AppColors.sub),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: AppTheme.body(14),
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) =>
                    (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                style: AppTheme.body(14),
                decoration: const InputDecoration(labelText: 'Password'),
                validator: (v) =>
                    (v == null || v.length < 6) ? 'At least 6 characters' : null,
              ),
              if (auth.error != null) ...[
                const SizedBox(height: 12),
                Text(auth.error!, style: AppTheme.body(12, color: AppColors.red)),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: auth.busy ? null : _submit,
                  child: auth.busy
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.black),
                        )
                      : Text(_isSignUp ? 'Sign up' : 'Sign in'),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () => setState(() => _isSignUp = !_isSignUp),
                  child: Text(
                    _isSignUp ? 'Already have an account? Sign in' : 'New here? Create an account',
                    style: AppTheme.body(13, color: AppColors.green),
                  ),
                ),
              ),
              if (!_isSignUp)
                Center(
                  child: TextButton(
                    onPressed: () async {
                      if (_emailController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Enter your email above first')),
                        );
                        return;
                      }
                      final err = await auth.sendPasswordReset(_emailController.text.trim());
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(err ?? 'Password reset email sent')),
                      );
                    },
                    child: Text('Forgot password?', style: AppTheme.body(12, color: AppColors.sub)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lighter-weight than PlayerCard — a pending/rejected submission doesn't
/// have Contact/Save/Watch actions that make sense yet, just a status.
class _SubmissionTile extends StatelessWidget {
  final Player player;
  const _SubmissionTile({required this.player});

  Color get _statusColor {
    switch (player.status) {
      case 'approved':
        return AppColors.green;
      case 'rejected':
        return AppColors.red;
      default:
        return AppColors.amber;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: _statusColor, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(player.name, style: AppTheme.body(14, weight: FontWeight.w600)),
                Text('${player.position.label} · ${player.country}', style: AppTheme.body(11, color: AppColors.sub)),
              ],
            ),
          ),
          Text(player.status.toUpperCase(), style: AppTheme.body(10, color: _statusColor, weight: FontWeight.bold)),
        ],
      ),
    );
  }
}

/// Checks real enrollment status (not assumed) and offers Enable/Disable
/// accordingly — see auth_provider.dart's MFA methods.
class _TwoFactorTile extends StatefulWidget {
  final AuthProvider auth;
  const _TwoFactorTile({required this.auth});

  @override
  State<_TwoFactorTile> createState() => _TwoFactorTileState();
}

class _TwoFactorTileState extends State<_TwoFactorTile> {
  late Future<Factor?> _factorFuture;

  @override
  void initState() {
    super.initState();
    _factorFuture = widget.auth.getVerifiedTotpFactor();
  }

  void _refresh() => setState(() => _factorFuture = widget.auth.getVerifiedTotpFactor());

  Future<void> _disable(String factorId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('Turn off 2FA?', style: AppTheme.display(16)),
        content: Text(
          'Your account will only need a password to sign in.',
          style: AppTheme.body(13, color: AppColors.sub),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Turn off', style: AppTheme.body(14, color: AppColors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final err = await widget.auth.disableMfa(factorId);
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Factor?>(
      future: _factorFuture,
      builder: (context, snapshot) {
        final enrolled = snapshot.data != null;
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            enrolled ? Icons.verified_user : Icons.shield_outlined,
            color: enrolled ? AppColors.green : AppColors.sub,
          ),
          title: Text('Two-factor authentication', style: AppTheme.body(14)),
          subtitle: Text(
            enrolled ? 'On' : 'Off — recommended for extra security',
            style: AppTheme.body(11, color: enrolled ? AppColors.green : AppColors.sub),
          ),
          onTap: () async {
            if (enrolled) {
              await _disable(snapshot.data!.id);
            } else {
              final result = await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => const MfaSetupScreen()),
              );
              if (result == true) _refresh();
            }
          },
        );
      },
    );
  }
}
