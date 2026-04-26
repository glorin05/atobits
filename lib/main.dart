import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'data/providers/habit_provider.dart';
import 'features/splash/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => HabitProvider()),
      ],
      child: const AtobisApp(),
    ),
  );
}

class AtobisApp extends StatelessWidget {
  const AtobisApp({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    return MaterialApp(
      title: 'Atobits',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      darkTheme: AppThemeDark.theme,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      home: const SplashScreen(),
    );
  }
}
