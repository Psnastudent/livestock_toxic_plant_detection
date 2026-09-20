import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'models/user_profile.dart';
import 'providers/location_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/intro_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  final initialUser = await getSavedUserProfile();

  runApp(
    ProviderScope(
      child: ToxicPlantApp(initialUser: initialUser),
    ),
  );
}

class ToxicPlantApp extends ConsumerStatefulWidget {
  final UserProfile? initialUser;
  const ToxicPlantApp({super.key, this.initialUser});

  @override
  ConsumerState<ToxicPlantApp> createState() => _ToxicPlantAppState();
}

class _ToxicPlantAppState extends ConsumerState<ToxicPlantApp> {
  @override
  void initState() {
    super.initState();
    if (widget.initialUser != null) {
      // Pre-seed authProvider notifier with saved profile
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(authProvider.notifier).saveProfile(widget.initialUser!);
      });
    }
    // Fetch live GPS location on every app launch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(locationProvider.notifier).initLocation();
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider) ?? widget.initialUser;
    final isProfileComplete = user != null && user.isProfileComplete;
    final themeMode = ref.watch(themeProvider);

    return MaterialApp(
      title: 'AgriGuard – Plant Safety',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: _lightTheme(),
      darkTheme: _darkTheme(),
      home: SplashScreen(
        nextScreen: IntroScreen(
          isLoggedIn: isProfileComplete,
          nextScreen: isProfileComplete ? const HomeScreen() : const LoginScreen(),
        ),
      ),
    );
  }

  ThemeData _darkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.transparent,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF2E7D32),
        primary: const Color(0xFF4CAF50),
        secondary: const Color(0xFF2E7D32),
        surface: const Color(0xFF1A231B),
        onSurface: const Color(0xFFEAEEEA),
        brightness: Brightness.dark,
      ),
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1A231B),
        foregroundColor: Color(0xFFEAEEEA),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: const Color(0xFF1A231B),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2E7D32),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
      ),
      dividerColor: const Color(0xFF2A332B),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  ThemeData _lightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: Colors.transparent,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF2E7D32),
        primary: const Color(0xFF2E7D32),
        secondary: const Color(0xFF1B5E20),
        surface: const Color(0xFFF3F7F3),
        onSurface: const Color(0xFF1A231B),
        brightness: Brightness.light,
      ),
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.light().textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF3F7F3),
        foregroundColor: Color(0xFF1A231B),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2E7D32),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
      ),
      dividerColor: const Color(0xFFE2EADF),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
