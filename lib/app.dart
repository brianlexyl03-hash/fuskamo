import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'localisation/app_localisations.dart';
import 'providers/auth_provider.dart';
import 'providers/nav_provider.dart';
import 'providers/group_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/player_provider.dart';
import 'providers/saved_players_provider.dart';
import 'providers/scout_provider.dart';
import 'providers/social_provider.dart';
import 'providers/unified_recommendation_provider.dart';
import 'routes/app_routes.dart';
import 'theme/app_theme.dart';

class FuskamoApp extends StatelessWidget {
  const FuskamoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => NavProvider()),
        ChangeNotifierProvider(create: (_) => GroupProvider()),
        ChangeNotifierProvider(create: (_) => PlayerProvider()),
        ChangeNotifierProvider(create: (_) => ScoutProvider()),
        ChangeNotifierProvider(create: (_) => SocialProvider()),
        ChangeNotifierProvider(create: (_) => UnifiedRecommendationProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        // Re-attaches to the signed-in user's id whenever AuthProvider
        // changes, so the notifications stream always matches whoever is
        // currently signed in (and clears on sign-out).
        ChangeNotifierProxyProvider<AuthProvider, NotificationProvider>(
          create: (_) => NotificationProvider(),
          update: (_, auth, notifications) {
            notifications ??= NotificationProvider();
            notifications.attachUser(auth.status == AuthStatus.signedIn ? auth.user?.id : null);
            return notifications;
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, SavedPlayersProvider>(
          create: (_) => SavedPlayersProvider(),
          update: (_, auth, saved) {
            saved ??= SavedPlayersProvider();
            saved.attachUser(auth.status == AuthStatus.signedIn ? auth.user?.id : null);
            return saved;
          },
        ),
      ],
      child: MaterialApp.router(
        title: 'FUSKAMO',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        routerConfig: AppRoutes.router,
        supportedLocales: AppLocalisations.supportedLocales,
        localizationsDelegates: const [
          AppLocalisations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
      ),
    );
  }
}
