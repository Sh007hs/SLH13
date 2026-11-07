import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(SLHHawkApp(initialLanguage: prefs.getString('language') ?? 'ar'));
}

class SLHHawkApp extends StatefulWidget {
  const SLHHawkApp({super.key, required this.initialLanguage});
  final String initialLanguage;
  @override
  State<SLHHawkApp> createState() => _SLHHawkAppState();
}

class _SLHHawkAppState extends State<SLHHawkApp> {
  late String language = widget.initialLanguage;
  Future<void> changeLanguage(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', value);
    setState(() => language = value);
  }

  @override
  Widget build(BuildContext context) {
    final arabic = language == 'ar';
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SLH_HAWK',
      locale: Locale(language),
      supportedLocales: const [Locale('ar'), Locale('fr')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFD71920)),
        scaffoldBackgroundColor: const Color(0xFFF4F5F7),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF111827),
          foregroundColor: Colors.white,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 1,
          margin: const EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      home: Directionality(
        textDirection: arabic ? TextDirection.rtl : TextDirection.ltr,
        child: HomeScreen(language: language, onLanguageChanged: changeLanguage),
      ),
    );
  }
}
