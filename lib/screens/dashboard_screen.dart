import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';


class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  TextStyle _getTextStyle(double fontSize, FontWeight fontWeight, Color color, String lang) {
    if (lang == 'ta') {
      return GoogleFonts.notoSansTamil(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
      );
    }
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(localeProvider);

    final user = ref.watch(authProvider);

    if (user == null) {
      return Scaffold(
        body: Center(
          child: Text(
            lang == 'ta' ? 'அணுகல் மறுக்கப்பட்டது' : 'Access Denied',
            style: const TextStyle(fontSize: 18),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          lang == 'ta' ? 'எனது சுயவிவரம்' : 'My Profile',
          style: _getTextStyle(18, FontWeight.bold, Colors.white, lang),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 16),
            // Profile Image with cached network image
            Center(
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFC8E6C9), width: 4),
                ),
                child: ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: user.photoUrl,
                    width: 110,
                    height: 110,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const SizedBox(
                      width: 110,
                      height: 110,
                      child: CircularProgressIndicator(color: Color(0xFF2E7D32)),
                    ),
                    errorWidget: (context, url, error) => const Icon(
                      Icons.account_circle,
                      size: 110,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Profile Name
            Text(
              user.name,
              style: _getTextStyle(24, FontWeight.bold, Colors.white, lang),
            ),
            const SizedBox(height: 4),

            // Profile Email
            Text(
              user.email,
              style: GoogleFonts.inter(fontSize: 14, color: Colors.white70),
            ),
            const SizedBox(height: 24),

            const Divider(),
            const SizedBox(height: 16),

            // Settings/Language Preferences Section
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                lang == 'ta' ? 'அமைப்புகள்' : 'Settings',
                style: _getTextStyle(16, FontWeight.bold, Colors.white, lang),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.language, color: Theme.of(context).colorScheme.secondary),
              title: Text(
                lang == 'ta' ? 'விருப்பமான மொழி' : 'Preferred Language',
                style: _getTextStyle(14, FontWeight.w500, Colors.white, lang),
              ),
              trailing: Text(
                lang == 'ta' ? 'தமிழ் (Tamil)' : 'English',
                style: _getTextStyle(14, FontWeight.bold, Theme.of(context).colorScheme.secondary, lang),
              ),
            ),
            const SizedBox(height: 24),

            // Mock Scan History Section
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                lang == 'ta' ? 'சமீபத்திய ஸ்கேன்கள் (5)' : 'Recent Scans (5)',
                style: _getTextStyle(16, FontWeight.bold, Colors.white, lang),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                children: [
                  Icon(Icons.history, color: Theme.of(context).colorScheme.secondary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      lang == 'ta'
                          ? 'ஸ்கேன் வரலாறு காலியாக உள்ளது.'
                          : 'Scan history is empty.',
                      style: _getTextStyle(14, FontWeight.normal, Colors.white, lang),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),

            // Logout Button (Large touch target)
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () {
                  ref.read(authProvider.notifier).state = null;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        lang == 'ta'
                            ? 'வெற்றிகரமாக வெளியேறினீர்கள்!'
                            : 'Logged out successfully!',
                      ),
                      backgroundColor: Colors.grey[800],
                    ),
                  );
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.logout, color: Colors.white),
                label: Text(
                  lang == 'ta' ? 'வெளியேறு' : 'Logout',
                  style: _getTextStyle(16, FontWeight.bold, Colors.white, lang),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC62828), // Crimson red
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
