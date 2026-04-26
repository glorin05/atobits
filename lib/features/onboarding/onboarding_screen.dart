import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main_shell.dart';
import '../../core/theme/app_theme.dart';
import '../../data/providers/habit_provider.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;

    final bg = isDark ? AppThemeDark.background : AppTheme.background;
    final primaryText =
        isDark ? AppThemeDark.primaryText : AppTheme.primaryText;
    final secondaryText =
        isDark ? AppThemeDark.secondaryText : AppTheme.secondaryText;
    final primaryBlue =
        isDark ? AppThemeDark.primaryBlue : AppTheme.primaryBlue;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'welcome.',
                  style: GoogleFonts.urbanist(
                    fontSize: 44,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.5,
                    color: primaryText,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Tracking built for focus and clarity.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.urbanist(
                    fontSize: 15,
                    height: 1.35,
                    color: secondaryText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 64),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBlue,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('has_onboarded', true);
                      if (context.mounted) {
                        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainShell()));
                      }
                    },
                    child: Text(
                      'Begin Tracker',
                      style: GoogleFonts.urbanist(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
