import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/theme_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import 'login_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final userProfile = ref.watch(authProvider);
    final lang = ref.watch(languageProvider);
    final isTamil = lang == AppLanguage.tamil;
    final tr = ref.read(translationProvider);
    String t(String key) => tr[key]?[isTamil ? 'tamil' : 'english'] ?? key;

    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(t('profile'),
                  style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w800,
                      color: Theme.of(context).textTheme.bodyLarge?.color)),
            ),
            const SizedBox(height: 40),

            // Avatar
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFE8F5E9),
                border: Border.all(color: const Color(0xFF2E7D32), width: 3),
              ),
              child: ClipOval(
                child: Image.network(
                  userProfile?.photoUrl ?? 'https://picsum.photos/200',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.person_rounded, size: 48, color: Color(0xFF2E7D32)),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(userProfile?.name ?? (isTamil ? 'விருந்தினர்' : 'Guest User'),
                style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w800,
                    color: Theme.of(context).textTheme.bodyLarge?.color)),
            const SizedBox(height: 6),
            Text(userProfile?.email ?? (isTamil ? 'உள்நுழையவில்லை' : 'Not logged in'),
                style: GoogleFonts.outfit(fontSize: 14,
                    color: Theme.of(context).textTheme.bodyMedium?.color)),
            const SizedBox(height: 36),

            // Settings
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10, offset: const Offset(0, 3))],
              ),
              child: Column(
                children: [
                  _tile(context,
                    icon: isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                    title: t('dark_mode'),
                    trailing: Switch(
                      value: isDark,
                      activeColor: const Color(0xFF2E7D32),
                      activeTrackColor: const Color(0xFF2E7D32).withValues(alpha: 0.3),
                      onChanged: (_) => ref.read(themeProvider.notifier).toggleTheme(),
                    ),
                  ),
                  Divider(color: Theme.of(context).dividerColor, height: 1, indent: 20, endIndent: 20),
                  _tile(context,
                    icon: Icons.language_rounded,
                    title: t('language'),
                    trailing: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _langChip('EN', !isTamil, () =>
                              ref.read(languageProvider.notifier).state = AppLanguage.english),
                          _langChip('தமிழ்', isTamil, () =>
                              ref.read(languageProvider.notifier).state = AppLanguage.tamil),
                        ],
                      ),
                    ),
                  ),
                  Divider(color: Theme.of(context).dividerColor, height: 1, indent: 20, endIndent: 20),
                  _tile(context, icon: Icons.info_outline_rounded, title: t('app_version')),
                ],
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity, height: 56,
              child: ElevatedButton.icon(
                onPressed: () {
                  ref.read(authProvider.notifier).state = null;
                  Navigator.pushAndRemoveUntil(context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false);
                },
                icon: const Icon(Icons.logout_rounded, size: 20),
                label: Text(t('logout'),
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[600],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _tile(BuildContext context,
      {required IconData icon, required String title, Widget? trailing}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: const Color(0xFF2E7D32), size: 20),
      ),
      title: Text(title,
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600,
              color: Theme.of(context).textTheme.bodyLarge?.color)),
      trailing: trailing,
    );
  }

  Widget _langChip(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF2E7D32) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label,
            style: GoogleFonts.outfit(
                fontSize: 12, fontWeight: FontWeight.w700,
                color: active ? Colors.white : const Color(0xFF2E7D32))),
      ),
    );
  }
}
