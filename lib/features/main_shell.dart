import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:quick_actions/quick_actions.dart';
import 'home/home_screen.dart';
import 'add_habit/add_habit_screen.dart';
import 'stats/stats_screen.dart';
import 'habits/habits_screen.dart';
import 'account/account_screen.dart';
import 'chat/ai_coach_screen.dart';
import '../core/theme/app_theme.dart';
import '../data/providers/habit_provider.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  final List<int> _tabHistory = <int>[];

  static const String _qaAddHabit = 'qa_add_habit';
  static const String _qaVoiceCoach = 'qa_voice_coach';

  final QuickActions _quickActions = const QuickActions();

  bool get _supportsQuickActions {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  @override
  void initState() {
    super.initState();
    _initQuickActions();
  }

  Future<void> _initQuickActions() async {
    if (!_supportsQuickActions) return;

    try {
      _quickActions.initialize((type) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _handleQuickAction(type);
        });
      });

      await _quickActions.setShortcutItems(
        const <ShortcutItem>[
          ShortcutItem(type: _qaAddHabit, localizedTitle: 'Add Habit'),
          ShortcutItem(type: _qaVoiceCoach, localizedTitle: 'Voice Coach'),
        ],
      );
    } catch (_) {
      // Ignore: quick actions aren't supported on all platforms/configurations.
    }
  }

  void _handleQuickAction(String type) {
    switch (type) {
      case _qaAddHabit:
        _openAddHabit();
        break;
      case _qaVoiceCoach:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const AICoachScreen(
              voiceOnly: true,
              autoStartListening: true,
            ),
          ),
        );
        break;
    }
  }

  void _onItemTapped(int index) {
    if (index == _currentIndex) return;
    HapticFeedback.lightImpact();
    setState(() {
      _tabHistory.add(_currentIndex);
      _currentIndex = index;
    });
  }

  void _handleBackNavigation() {
    if (_tabHistory.isNotEmpty) {
      setState(() => _currentIndex = _tabHistory.removeLast());
      return;
    }

    if (_currentIndex != 0) {
      setState(() => _currentIndex = 0);
    }
  }

  void _openAddHabit() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddHabitScreen(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final primaryBlue =
        isDark ? AppThemeDark.primaryBlue : AppTheme.primaryBlue;
    final inactiveColor = isDark ? AppThemeDark.mutedText : AppTheme.mutedText;

    final screens = [
      HomeScreen(onOpenAnalytics: () => _onItemTapped(2)),
      const HabitsScreen(),
      const StatsScreen(),
      const AccountScreen(),
    ];

    return PopScope(
      canPop: _currentIndex == 0 && _tabHistory.isEmpty,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _handleBackNavigation();
        });
      },
      child: Stack(
        children: [
          Scaffold(
            backgroundColor:
                isDark ? AppThemeDark.background : AppTheme.background,
            body: IndexedStack(index: _currentIndex, children: screens),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: Center(
              child: SizedBox(
                width: 296,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.white : Colors.black)
                            .withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                            width: 1),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 4))
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildNavItem(0, Icons.home_outlined, Icons.home,
                              primaryBlue, inactiveColor),
                          _buildNavItem(
                              1,
                              Icons.format_list_bulleted_outlined,
                              Icons.format_list_bulleted,
                              primaryBlue,
                              inactiveColor),
                          _buildAddBtn(primaryBlue),
                          _buildNavItem(2, Icons.insights_outlined,
                              Icons.insights, primaryBlue, inactiveColor),
                          _buildNavItem(3, Icons.person_outline, Icons.person,
                              primaryBlue, inactiveColor),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData outlinedIcon, IconData filledIcon,
      Color accentColor, Color inactiveColor) {
    final isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(isSelected ? filledIcon : outlinedIcon,
            color: isSelected ? accentColor : inactiveColor, size: 22),
      ),
    );
  }

  Widget _buildAddBtn(Color accentColor) {
    return GestureDetector(
      onTap: _openAddHabit,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: accentColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 22),
      ),
    );
  }
}
