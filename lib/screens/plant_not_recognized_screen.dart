import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';

import '../models/classification_result.dart';
import '../providers/language_provider.dart';
import 'report_plant_screen.dart';
import 'scan_screen.dart';

/// Screen shown when the AI could not confidently identify a plant.
///
/// Displays:
/// - The photo that was scanned
/// - Top-N low-confidence suggestions (if any)
/// - "Report This Plant" button → Firebase reporting
/// - "Try Another Photo" button → back to scanner
/// - Tips for better photo quality
class PlantNotRecognizedScreen extends ConsumerWidget {
  final File imageFile;
  final ClassificationResult result;

  const PlantNotRecognizedScreen({
    super.key,
    required this.imageFile,
    required this.result,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final isTamil = lang == AppLanguage.tamil;
    final tr = ref.read(translationProvider);
    String t(String key) => tr[key]?[isTamil ? 'tamil' : 'english'] ?? key;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF1A1025),
                  Color(0xFF0A0E1A),
                  Color(0xFF0D1520),
                ],
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 16),

                  // Back button row
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                          ),
                          child: const Icon(Icons.arrow_back_ios_new_rounded,
                              color: Colors.white70, size: 18),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          t('not_recognized_title'),
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Warning icon with glow
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFA726), Color(0xFFFF7043)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFA726).withValues(alpha: 0.4),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.help_outline_rounded,
                        color: Colors.white, size: 40),
                  ),

                  const SizedBox(height: 16),

                  Text(
                    t('not_recognized_subtitle'),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      color: Colors.white70,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Photo thumbnail with glass card
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.file(
                            imageFile,
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Top suggestions (if available)
                  if (result.topPredictions.isNotEmpty)
                    _buildSuggestionsCard(t, isTamil),

                  const SizedBox(height: 16),

                  // Action buttons
                  _buildReportButton(context, t),
                  const SizedBox(height: 12),
                  _buildRetryButton(context, t),

                  const SizedBox(height: 24),

                  // Tips card
                  _buildTipsCard(t),

                  const SizedBox(height: 16),

                  // AI Disclaimer
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded,
                            color: Colors.white.withValues(alpha: 0.3), size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            ClassificationResult.aiDisclaimer,
                            style: GoogleFonts.outfit(
                              color: Colors.white.withValues(alpha: 0.35),
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsCard(String Function(String) t, bool isTamil) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.lightbulb_outline_rounded,
                      color: Colors.amber.shade300, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    t('low_confidence_suggestions'),
                    style: GoogleFonts.outfit(
                      color: Colors.amber.shade200,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...result.topPredictions.take(3).map((pred) {
                final confPercent = (pred.confidence * 100).toStringAsFixed(0);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      // Confidence bar
                      Expanded(
                        flex: 3,
                        child: Text(
                          pred.label,
                          style: GoogleFonts.outfit(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 80,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pred.confidence,
                            minHeight: 6,
                            backgroundColor: Colors.white.withValues(alpha: 0.08),
                            valueColor: AlwaysStoppedAnimation(
                              pred.confidence > 0.5
                                  ? Colors.amber.shade400
                                  : Colors.white.withValues(alpha: 0.3),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 36,
                        child: Text(
                          '$confPercent%',
                          textAlign: TextAlign.end,
                          style: GoogleFonts.outfit(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportButton(BuildContext context, String Function(String) t) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReportPlantScreen(
              imageFile: imageFile,
              aiSuggestions: result.topPredictions
                  .map((p) => '${p.label} (${p.confidencePercent})')
                  .toList(),
            ),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFA726), Color(0xFFFF7043)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFA726).withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(
              t('report_this_plant'),
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRetryButton(BuildContext context, String Function(String) t) {
    return GestureDetector(
      onTap: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ScanScreen()),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.refresh_rounded, color: Colors.white70, size: 20),
            const SizedBox(width: 10),
            Text(
              t('try_another_photo'),
              style: GoogleFonts.outfit(
                color: Colors.white70,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipsCard(String Function(String) t) {
    final tips = [
      {'icon': Icons.zoom_in_rounded, 'key': 'tip_closer'},
      {'icon': Icons.light_mode_rounded, 'key': 'tip_lighting'},
      {'icon': Icons.eco_rounded, 'key': 'tip_leaves'},
      {'icon': Icons.center_focus_strong_rounded, 'key': 'tip_focus'},
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.tips_and_updates_rounded,
                      color: Colors.tealAccent.shade200, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    t('tips_title'),
                    style: GoogleFonts.outfit(
                      color: Colors.tealAccent.shade200,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...tips.map((tip) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(tip['icon'] as IconData,
                            color: Colors.white.withValues(alpha: 0.4), size: 16),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            t(tip['key'] as String),
                            style: GoogleFonts.outfit(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }
}
