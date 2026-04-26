import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../data/providers/habit_provider.dart';
import '../notifications/notifications_settings_screen.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;

    final bg = isDark ? AppThemeDark.background : AppTheme.background;
    final surface = isDark ? AppThemeDark.surface : AppTheme.surface;
    final primaryText =
        isDark ? AppThemeDark.primaryText : AppTheme.primaryText;
    final secondaryText =
        isDark ? AppThemeDark.secondaryText : AppTheme.secondaryText;
    final primaryBlue =
        isDark ? AppThemeDark.primaryBlue : AppTheme.primaryBlue;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            SliverAppBar(
              floating: true,
              backgroundColor: bg,
              elevation: 0,
              title: Text('Account',
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: primaryText)),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 140),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildProfileCard(
                      primaryText, secondaryText, surface, primaryBlue),
                  const SizedBox(height: 24),
                  _buildSettingsSection(
                      context,
                      'Settings',
                      [
                        _buildSettingsItem(
                          context,
                          Icons.dark_mode_outlined,
                          'Dark Mode',
                          'Switch to dark theme',
                          trailing: Switch(
                            value: isDark,
                            onChanged: (_) => themeProvider.toggleTheme(),
                            activeThumbColor: primaryBlue,
                          ),
                        ),
                        _buildSettingsItem(
                            context,
                            Icons.notifications_outlined,
                            'Notifications',
                            'Manage reminders', onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const NotificationsSettingsScreen(),
                            ),
                          );
                        }),
                        _buildSettingsItem(
                            context, Icons.language, 'Language', 'English'),
                      ],
                      primaryBlue),
                  const SizedBox(height: 24),
                  _buildSettingsSection(
                      context,
                      'About',
                      [
                        _buildSettingsItem(context, Icons.info_outline,
                            'About Atobits', 'Version 1.0.0'),
                        _buildSettingsItem(context, Icons.privacy_tip_outlined,
                            'Privacy Policy', 'Learn how we handle your data'),
                        _buildSettingsItem(context, Icons.description_outlined,
                            'Terms of Service', 'Read our terms'),
                      ],
                      primaryBlue),
                  const SizedBox(height: 24),
                  Center(
                    child: Text('Atobits v1.0.0',
                        style: TextStyle(color: secondaryText, fontSize: 14)),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard(Color primaryText, Color secondaryText,
      Color surface, Color primaryBlue) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: primaryBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.person, color: primaryBlue, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Guest User',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: primaryText)),
                const SizedBox(height: 4),
                Text('Tap to sign in',
                    style: TextStyle(color: secondaryText, fontSize: 14)),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: secondaryText),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(BuildContext context, String title,
      List<Widget> items, Color primaryBlue) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final surface = isDark ? AppThemeDark.surface : AppTheme.surface;
    final secondaryText =
        isDark ? AppThemeDark.secondaryText : AppTheme.secondaryText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: secondaryText)),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(children: items),
        ),
      ],
    );
  }

  Widget _buildSettingsItem(
      BuildContext context, IconData icon, String title, String subtitle,
      {Widget? trailing, VoidCallback? onTap}) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final primaryText =
        isDark ? AppThemeDark.primaryText : AppTheme.primaryText;
    final secondaryText =
        isDark ? AppThemeDark.secondaryText : AppTheme.secondaryText;
    final mutedText = isDark ? AppThemeDark.mutedText : AppTheme.mutedText;
    final primaryBlue =
        isDark ? AppThemeDark.primaryBlue : AppTheme.primaryBlue;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: primaryBlue, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: primaryText)),
                  Text(subtitle,
                      style: TextStyle(fontSize: 13, color: secondaryText)),
                ],
              ),
            ),
            trailing ?? Icon(Icons.chevron_right, color: mutedText),
          ],
        ),
      ),
    );
  }
}
