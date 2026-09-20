import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';

import '../providers/language_provider.dart';
import '../providers/location_provider.dart';
import '../services/plant_report_service.dart';

/// Screen where users can report an unidentified plant to Firebase.
///
/// Collects:
/// - 📷 Photo (auto-attached from scan)
/// - 📝 Plant name (if known by user)
/// - 📋 Additional notes
/// - 📍 Location (auto-detected)
/// - 🤖 AI suggestions (passed from classification)
class ReportPlantScreen extends ConsumerStatefulWidget {
  final File imageFile;
  final List<String>? aiSuggestions;

  const ReportPlantScreen({
    super.key,
    required this.imageFile,
    this.aiSuggestions,
  });

  @override
  ConsumerState<ReportPlantScreen> createState() => _ReportPlantScreenState();
}

class _ReportPlantScreenState extends ConsumerState<ReportPlantScreen> {
  final _plantNameController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isSubmitting = false;
  bool _isSubmitted = false;

  @override
  void dispose() {
    _plantNameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    setState(() => _isSubmitting = true);

    // Get position from centralized location provider
    final currentPosition = ref.read(locationProvider).position;

    final success = await PlantReportService.submitReport(
      imageFile: widget.imageFile,
      plantName: _plantNameController.text.trim().isNotEmpty
          ? _plantNameController.text.trim()
          : null,
      additionalNotes: _notesController.text.trim().isNotEmpty
          ? _notesController.text.trim()
          : null,
      aiSuggestions: widget.aiSuggestions,
      currentPosition: currentPosition,
    );

    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
      _isSubmitted = success;
    });

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Report submitted successfully! Thank you for helping improve the app.',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w500),
          ),
          backgroundColor: const Color(0xFF2E7D32),
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to submit report. Please check your internet connection.',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w500),
          ),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),

                  // Header
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.06)),
                          ),
                          child: const Icon(Icons.arrow_back_ios_new_rounded,
                              color: Colors.white70, size: 18),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          t('report_plant_title'),
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      t('report_plant_subtitle'),
                      style: GoogleFonts.outfit(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 13,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Success state
                  if (_isSubmitted) ...[
                    _buildSuccessCard(t),
                    const SizedBox(height: 20),
                    _buildDoneButton(context, t),
                  ] else ...[
                    // Photo preview
                    _buildPhotoPreview(),
                    const SizedBox(height: 20),

                    // AI suggestions info
                    if (widget.aiSuggestions != null &&
                        widget.aiSuggestions!.isNotEmpty) ...[
                      _buildAiSuggestionsInfo(t),
                      const SizedBox(height: 16),
                    ],

                    // Plant name input
                    _buildInputField(
                      controller: _plantNameController,
                      label: t('report_plant_name_label'),
                      hint: t('report_plant_name_hint'),
                      icon: Icons.eco_rounded,
                    ),
                    const SizedBox(height: 16),

                    // Additional notes input
                    _buildInputField(
                      controller: _notesController,
                      label: t('report_notes_label'),
                      hint: t('report_notes_hint'),
                      icon: Icons.notes_rounded,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),

                    // Location auto-detect note
                    Row(
                      children: [
                        Icon(Icons.location_on_rounded,
                            color: Colors.tealAccent.withValues(alpha: 0.5),
                            size: 14),
                        const SizedBox(width: 6),
                        Text(
                          t('report_location_auto'),
                          style: GoogleFonts.outfit(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // Submit button
                    _buildSubmitButton(t),
                  ],

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoPreview() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(20),
            border:
                Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.file(
                  widget.imageFile,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_rounded,
                      color: Colors.tealAccent.shade200, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    'Photo attached',
                    style: GoogleFonts.outfit(
                      color: Colors.tealAccent.shade200,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAiSuggestionsInfo(String Function(String) t) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.smart_toy_rounded,
                  color: Colors.amber.shade300, size: 16),
              const SizedBox(width: 8),
              Text(
                t('report_ai_suggestions'),
                style: GoogleFonts.outfit(
                  color: Colors.amber.shade200,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...widget.aiSuggestions!.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '• $s',
                  style: GoogleFonts.outfit(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white.withValues(alpha: 0.4), size: 16),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.outfit(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '(optional)',
              style: GoogleFonts.outfit(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.outfit(
                color: Colors.white.withValues(alpha: 0.25),
                fontSize: 14,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton(String Function(String) t) {
    return GestureDetector(
      onTap: _isSubmitting ? null : _submitReport,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: _isSubmitting
              ? null
              : const LinearGradient(
                  colors: [Color(0xFF26A69A), Color(0xFF00897B)],
                ),
          color: _isSubmitting ? Colors.white.withValues(alpha: 0.06) : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: _isSubmitting
              ? []
              : [
                  BoxShadow(
                    color: const Color(0xFF26A69A).withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isSubmitting)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white70,
                ),
              )
            else
              const Icon(Icons.cloud_upload_rounded,
                  color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(
              _isSubmitting ? t('report_submitting') : t('report_submit'),
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

  Widget _buildSuccessCard(String Function(String) t) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.tealAccent.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: Colors.tealAccent.withValues(alpha: 0.15)),
          ),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Colors.tealAccent.shade400,
                      Colors.teal.shade600,
                    ],
                  ),
                ),
                child: const Icon(Icons.check_rounded,
                    color: Colors.white, size: 34),
              ),
              const SizedBox(height: 16),
              Text(
                t('report_success_title'),
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                t('report_success_subtitle'),
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDoneButton(BuildContext context, String Function(String) t) {
    return GestureDetector(
      onTap: () {
        // Pop back to the scan screen or home
        Navigator.popUntil(context, (route) => route.isFirst);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF26A69A), Color(0xFF00897B)],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.home_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(
              t('report_done'),
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
}
