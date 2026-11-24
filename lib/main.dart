import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:monu/config/supabase_config.dart';
import 'package:monu/core/app_info.dart';
import 'package:monu/core/app_theme.dart';
import 'package:monu/core/routes.dart';
import 'package:monu/providers/auth_provider.dart';
import 'package:monu/providers/monitor_provider.dart';
import 'package:monu/providers/settings_provider.dart';
import 'package:monu/screens/login_screen.dart';
import 'package:monu/screens/main_shell.dart';
import 'package:monu/screens/onboarding_screen.dart';
import 'package:monu/widgets/phone_frame.dart';
import 'package:provider/provider.dart';
import 'package:monu/providers/assistant_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Helper client global untuk mengakses database Supabase (PostgreSQL)
final SupabaseClient supabase = Supabase.instance.client;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi database Supabase (PostgreSQL)
  await Supabase.initialize(
    url: SupabaseConfig.url,
    // ignore: deprecated_member_use
    anonKey: SupabaseConfig.anonKey,
  );

  final SettingsProvider settings = SettingsProvider();
  final AuthProvider auth = AuthProvider();
  await Future.wait<void>(<Future<void>>[settings.load(), auth.load()]);

  runApp(MonuApp(settings: settings, auth: auth));
}

class MonuApp extends StatelessWidget {
  const MonuApp({super.key, required this.settings, required this.auth});

  final SettingsProvider settings;
  final AuthProvider auth;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsProvider>.value(value: settings),
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProvider<MonitorProvider>(
          lazy: false,
          create: (ctx) => MonitorProvider(ctx.read<SettingsProvider>()),
        ),
        ChangeNotifierProvider<AssistantProvider>(
          create: (ctx) => AssistantProvider(
            monitor: ctx.read<MonitorProvider>(),
            settings: ctx.read<SettingsProvider>(),
          )..load(),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: AppInfo.appName,
        theme: AppTheme.light(),
        locale: const Locale('id', 'ID'),
        supportedLocales: const [Locale('id', 'ID'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: (context, child) =>
            PhoneFrame(child: child ?? const SizedBox.shrink()),
        // Sudah login -> langsung ke app. Belum -> onboarding lalu login.
        home: Consumer<AuthProvider>(
          builder: (context, auth, _) =>
              auth.isLoggedIn ? const MainShell() : const _Welcome(),
        ),
      ),
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome();

  @override
  Widget build(BuildContext context) {
    return OnboardingScreen(
      onEnter: () =>
          Navigator.of(context).push(fadeRoute(const LoginScreen())),
    );
  }
}