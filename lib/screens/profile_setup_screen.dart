import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/user_profile.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../widgets/themed_background.dart';
import '../widgets/glass_card.dart';
import 'home_screen.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  final bool isEditing;
  const ProfileSetupScreen({super.key, this.isEditing = false});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _villageController;
  late TextEditingController _livestockController;

  @override
  void initState() {
    super.initState();
    final currentProfile = ref.read(authProvider);
    _nameController = TextEditingController(text: currentProfile?.name ?? '');
    _phoneController = TextEditingController(text: currentProfile?.phoneNumber ?? '');
    _villageController = TextEditingController(text: currentProfile?.village ?? '');
    _livestockController = TextEditingController(
      text: currentProfile != null && currentProfile.livestockCount > 0
          ? currentProfile.livestockCount.toString()
          : '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _villageController.dispose();
    _livestockController.dispose();
    super.dispose();
  }

  void _saveProfile() {
    if (_formKey.currentState!.validate()) {
      final current = ref.read(authProvider);
      final count = int.tryParse(_livestockController.text.trim()) ?? 0;

      final updatedProfile = (current ??
              UserProfile(
                uid: 'user_${DateTime.now().millisecondsSinceEpoch}',
                name: _nameController.text.trim(),
                email: 'farmer@agriguard.app',
                photoUrl: 'https://picsum.photos/id/433/200/200',
                loginMethod: 'Phone/Direct',
                createdAt: DateTime.now(),
              ))
          .copyWith(
        name: _nameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        village: _villageController.text.trim(),
        livestockCount: count,
        isProfileComplete: true,
      );

      ref.read(authProvider.notifier).saveProfile(updatedProfile);

      if (widget.isEditing) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Color(0xFF2E7D32),
          ),
        );
        Navigator.pop(context);
      } else {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const HomeScreen(),
            transitionDuration: const Duration(milliseconds: 500),
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final isTamil = lang == AppLanguage.tamil;

    return ThemedBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: widget.isEditing
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                )
              : null,
          title: Text(
            widget.isEditing
                ? (isTamil ? 'சுயவிவரத்தை திருத்து' : 'Edit Profile')
                : (isTamil ? 'சுயவிவர அமைவு' : 'Profile Setup'),
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w700,
              fontSize: 20,
              color: Colors.white,
            ),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title Card
                  GlassCard(
                    borderRadius: 20,
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2E7D32).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.person_pin_rounded,
                            color: Color(0xFF2E7D32),
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.isEditing
                                    ? (isTamil ? 'விவரங்களை புதுப்பிக்கவும்' : 'Update Details')
                                    : (isTamil ? 'வரவேற்கிறோம்!' : 'Welcome Farmer!'),
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Theme.of(context).textTheme.bodyLarge?.color,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isTamil
                                    ? 'உங்கள் கால்நடை பாதுகாப்பு கணக்கை அமைக்க உங்கள் விவரங்களை உள்ளிடவும்'
                                    : 'Please fill in your details to customize your safety alerts',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  color: Theme.of(context).textTheme.bodyMedium?.color,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Form Fields
                  _buildLabel(isTamil ? 'முழு பெயர்' : 'Full Name', Icons.person_rounded),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _nameController,
                    hint: isTamil ? 'எ.கா: ராமன்' : 'e.g. Ramesh Kumar',
                    validator: (val) => val == null || val.trim().isEmpty
                        ? (isTamil ? 'பெயரை உள்ளிடவும்' : 'Please enter your name')
                        : null,
                  ),
                  const SizedBox(height: 20),

                  _buildLabel(isTamil ? 'தொலைபேசி எண்' : 'Phone Number', Icons.phone_rounded),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _phoneController,
                    hint: isTamil ? 'எ.கா: 9876543210' : 'e.g. 9876543210',
                    keyboardType: TextInputType.phone,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return isTamil
                            ? 'தொலைபேசி எண்ணை உள்ளிடவும்'
                            : 'Please enter phone number';
                      }
                      if (val.trim().length < 10) {
                        return isTamil
                            ? 'செல்லுபடியாகும் 10 இலக்க எண்ணை உள்ளிடவும்'
                            : 'Please enter a valid 10-digit phone number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  _buildLabel(isTamil ? 'கிராமம் / இடம்' : 'Village / Location', Icons.location_city_rounded),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _villageController,
                    hint: isTamil ? 'எ.கா: கோயம்புத்தூர்' : 'e.g. Coimbatore, Erode',
                    validator: (val) => val == null || val.trim().isEmpty
                        ? (isTamil ? 'கிராமத்தின் பெயரை உள்ளிடவும்' : 'Please enter village name')
                        : null,
                  ),
                  const SizedBox(height: 20),

                  _buildLabel(isTamil ? 'கால்நடைகளின் எண்ணிக்கை' : 'Number of Livestock', Icons.pets_rounded),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _livestockController,
                    hint: isTamil ? 'எ.கா: 5 (பசுக்கள்/ஆடுகள்)' : 'e.g. 5 (Cows / Goats / Sheep)',
                    keyboardType: TextInputType.number,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return isTamil
                            ? 'எண்ணிக்கையை உள்ளிடவும்'
                            : 'Please enter livestock count';
                      }
                      final num = int.tryParse(val.trim());
                      if (num == null || num < 0) {
                        return isTamil
                            ? 'சரியான எண்ணை உள்ளிடவும்'
                            : 'Please enter a valid number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 36),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        elevation: 4,
                      ),
                      child: Text(
                        widget.isEditing
                            ? (isTamil ? 'மாற்றங்களைச் சேமி' : 'Save Changes')
                            : (isTamil ? 'சுயவிவரத்தை முடித்துத் தொடரவும்' : 'Complete Setup & Continue'),
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF81C784)),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return GlassCard(
      borderRadius: 16,
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        style: GoogleFonts.outfit(
          color: Theme.of(context).textTheme.bodyLarge?.color,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.outfit(
            color: Theme.of(context).hintColor,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          filled: false,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        ),
      ),
    );
  }
}
