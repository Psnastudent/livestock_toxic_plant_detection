import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/language_provider.dart';

class IntroScreen extends ConsumerWidget {
  final bool isLoggedIn;
  final Widget nextScreen;

  const IntroScreen({
    super.key,
    required this.isLoggedIn,
    required this.nextScreen,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final isTamil = lang == AppLanguage.tamil;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Forest Background
          Positioned.fill(
            child: Image.network(
              'https://images.unsplash.com/photo-1542273917363-3b1817f69a2d?auto=format&fit=crop&w=800&q=80',
              fit: BoxFit.cover,
            ),
          ),
          // Dark Gradient Overlay for readability
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.1),
                    Colors.black.withValues(alpha: 0.8),
                    Colors.black.withValues(alpha: 0.95),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          
          // Language Toggle Top Left
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 24,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => ref.read(languageProvider.notifier).state = AppLanguage.english,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: !isTamil ? Colors.white.withValues(alpha: 0.2) : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('EN', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => ref.read(languageProvider.notifier).state = AppLanguage.tamil,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isTamil ? Colors.white.withValues(alpha: 0.2) : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('தமிழ்', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Main Content Bottom
          Positioned(
            bottom: 40,
            left: 24,
            right: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isTamil ? 'உங்கள்\nகால்நடைகளை\nபாதுகாக்கவும்' : 'Protect\nYour\nLivestock',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  isTamil ? 'கால்நடைகளை பாதுகாக்கவும் · நச்சு தாவரங்களை கண்டறியவும்' : 'Protect livestock · Identify toxic plants',
                  style: GoogleFonts.outfit(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 32),
                
                // Stats Glass Card
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildStat(isTamil ? '22+' : '22+', isTamil ? 'தாவரங்கள்' : 'Plants'),
                          Container(width: 1, height: 40, color: Colors.white.withValues(alpha: 0.2)),
                          _buildStat(isTamil ? 'AI' : 'AI', isTamil ? 'கண்டறிதல்' : 'Detection'),
                          Container(width: 1, height: 40, color: Colors.white.withValues(alpha: 0.2)),
                          _buildStat(isTamil ? 'நேரலை' : 'Live', isTamil ? 'இடம்' : 'Location'),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                
                // Get Started Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => nextScreen),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF388E3C),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          isLoggedIn 
                              ? (isTamil ? 'உள்ளே செல்லுங்கள்' : 'Get In')
                              : (isTamil ? 'தொடங்குங்கள்' : 'Get Started'),
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String val, String label) {
    return Column(
      children: [
        Text(
          val,
          style: GoogleFonts.outfit(
            color: const Color(0xFF81C784),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.outfit(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
