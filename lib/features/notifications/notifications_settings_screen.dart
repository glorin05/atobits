import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/notifications/notification_service.dart';
import '../../core/services/system_settings_service.dart';
import '../../core/theme/app_theme.dart';
import '../../data/providers/habit_provider.dart';

class NotificationsSettingsScreen extends StatefulWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  State<NotificationsSettingsScreen> createState() =>
      _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState
    extends State<NotificationsSettingsScreen> {
  bool? _notificationsEnabled;
  bool? _ignoringBatteryOptimizations;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    bool? enabled;
    try {
      enabled = await NotificationService.areNotificationsEnabled();
    } catch (_) {
      enabled = null;
    }
    bool? ignoringBattery;
    try {
      ignoringBattery =
          await SystemSettingsService.isIgnoringBatteryOptimizations();
    } catch (_) {
      ignoringBattery = null;
    }

    if (!mounted) return;
    setState(() {
      _notificationsEnabled = enabled;
      _ignoringBatteryOptimizations = ignoringBattery;
    });
  }

  Future<void> _runGuarded(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Something went wrong. Please try again.',
            style: GoogleFonts.urbanist(fontWeight: FontWeight.w600),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
      if (mounted) await _refreshStatus();
    }
  }

  bool get _isReady {
    final notificationsOk = _notificationsEnabled == true;
    // On iOS / older Android, this can be null; treat null as "unknown" and
    // avoid blocking the ready state.
    final batteryOk = _ignoringBatteryOptimizations != false;
    return notificationsOk && batteryOk;
  }

  String _primaryMessage(int enabledReminderCount) {
    if (enabledReminderCount == 0) {
      return 'Turn on reminders for a habit to get daily notifications.';
    }

    if (_isReady) {
      return 'You\'re all set. Your habit reminders will arrive daily.';
    }

    return 'To receive reminders reliably, allow notifications and set battery to unrestricted.';
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;

    final habits = context.watch<HabitProvider>().habits;
    final enabledReminderCount = habits.where((h) => h.reminderEnabled).length;

    final bg = isDark ? AppThemeDark.background : AppTheme.background;
    final surface = isDark ? AppThemeDark.surface : AppTheme.surface;
    final primaryText =
        isDark ? AppThemeDark.primaryText : AppTheme.primaryText;
    final secondaryText =
        isDark ? AppThemeDark.secondaryText : AppTheme.secondaryText;
    final primaryBlue =
        isDark ? AppThemeDark.primaryBlue : AppTheme.primaryBlue;
    final border = isDark ? AppThemeDark.whisperBorder : AppTheme.whisperBorder;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text(
          'Notifications',
          style: GoogleFonts.urbanist(
            color: primaryText,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.6,
          ),
        ),
        iconTheme: IconThemeData(color: primaryText),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: primaryBlue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.notifications_active_outlined,
                        color: primaryBlue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Habit reminders',
                            style: GoogleFonts.urbanist(
                              color: primaryText,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _primaryMessage(enabledReminderCount),
                            style: GoogleFonts.urbanist(
                              color: secondaryText,
                              fontSize: 12,
                              height: 1.35,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _busy
                            ? null
                            : () => _runGuarded(() async {
                                  if (_notificationsEnabled == true) {
                                    await SystemSettingsService
                                        .openAppNotificationSettings();
                                  } else {
                                    await NotificationService
                                        .requestNotificationsPermission();
                                  }
                                }),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBlue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          _notificationsEnabled == true
                              ? 'Notification settings'
                              : 'Enable notifications',
                          style: GoogleFonts.urbanist(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () => _runGuarded(() async {
                                  await SystemSettingsService
                                      .requestIgnoreBatteryOptimizations();
                                }),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryBlue,
                          side: BorderSide(color: border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          'Unrestricted battery',
                          style: GoogleFonts.urbanist(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            enabledReminderCount == 0
                ? 'Tip: turn on Reminder when creating or editing a habit.'
                : 'Tip: if a reminder ever feels late, set battery to unrestricted for best reliability.',
            style: GoogleFonts.urbanist(
              color: secondaryText,
              fontSize: 12,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
