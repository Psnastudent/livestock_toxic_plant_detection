import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

import '../providers/theme_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../providers/location_provider.dart';
import '../data/vet_hospitals.dart';
import 'login_screen.dart';
import 'profile_setup_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final MapController _mapController = MapController();
  bool _mapMoved = false;

  Future<void> _makePhoneCall(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone.replaceAll(' ', ''));
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _pickProfilePicture() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (pickedFile != null) {
        final profile = ref.read(authProvider);
        if (profile != null) {
          final updatedProfile = profile.copyWith(photoUrl: pickedFile.path);
          ref.read(authProvider.notifier).saveProfile(updatedProfile);
        }
      }
    } catch (e) {
      debugPrint('Error picking profile picture: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    final lang = ref.watch(languageProvider);
    final isTamil = lang == AppLanguage.tamil;
    final userProfile = ref.watch(authProvider);

    // Read centralized location state
    final locState = ref.watch(locationProvider);
    final _currentPosition = locState.position;
    final _isLocationEnabled = locState.isLocationEnabled;
    final _nearestHospital = locState.nearestHospital;
    final _distanceKm = locState.distanceKm;
    final _nearbyHospitals = locState.nearbyHospitals;

    // Move map to user's position once when it becomes available
    if (_currentPosition != null && !_mapMoved) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _mapController.move(
            LatLng(_currentPosition.latitude, _currentPosition.longitude),
            13.5,
          );
          _mapMoved = true;
        }
      });
    }

    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    final userName = userProfile?.name.isNotEmpty == true
        ? userProfile!.name
        : (isTamil ? 'சந்தோஷ் குமார்' : 'Santhosh Kumar');
    final phone = userProfile?.phoneNumber.isNotEmpty == true
        ? userProfile!.phoneNumber
        : '6379540430';
    final village = userProfile?.village.isNotEmpty == true
        ? userProfile!.village
        : 'Madurai';
    final livestock = userProfile != null ? '${userProfile.livestockCount}' : '3';

    const primaryGreen = Color(0xFF264633);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF101C14) : primaryGreen,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              // ── Top Header Section (Green Background like Image 5) ──
              Container(
                color: isDark ? const Color(0xFF101C14) : primaryGreen,
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
                child: Column(
                  children: [
                    // App Bar Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            if (Navigator.canPop(context))
                              IconButton(
                                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                                    color: Colors.white, size: 20),
                                onPressed: () => Navigator.pop(context),
                              ),
                            Text(
                              isTamil ? 'சுயவிவரம்' : 'Profile',
                              style: GoogleFonts.outfit(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ProfileSetupScreen(isEditing: true),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.settings_rounded,
                                color: Colors.white, size: 20),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // User Profile Row (Avatar + Name + Subtitle)
                    Row(
                      children: [
                        Stack(
                          children: [
                            GestureDetector(
                              onTap: _pickProfilePicture,
                              child: Container(
                                width: 76,
                                height: 76,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.2),
                                  border: Border.all(color: Colors.white, width: 2.5),
                                  image: DecorationImage(
                                    image: (userProfile?.photoUrl.startsWith('http') == true)
                                        ? NetworkImage(userProfile!.photoUrl) as ImageProvider
                                        : (userProfile?.photoUrl.isNotEmpty == true
                                            ? FileImage(File(userProfile!.photoUrl)) as ImageProvider
                                            : const NetworkImage('https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=400&q=80')),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF4CAF50),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check_rounded,
                                    color: Colors.white, size: 12),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              left: 0,
                              child: GestureDetector(
                                onTap: _pickProfilePicture,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: primaryGreen,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 1.5),
                                  ),
                                  child: const Icon(Icons.edit_rounded,
                                      color: Colors.white, size: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userName,
                                style: GoogleFonts.outfit(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isTamil ? 'சரிபார்க்கப்பட்ட விவசாயி' : 'Verified Livestock Farmer',
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(Icons.location_on_outlined,
                                      color: Colors.white.withValues(alpha: 0.9), size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$village, Tamil Nadu',
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white.withValues(alpha: 0.9),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // Metrics / Stats Row (Image 5 style stats bar)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _statItem(
                            value: livestock,
                            label: isTamil ? 'விலங்குகள்' : 'LIVESTOCK',
                          ),
                          Container(
                            height: 32,
                            width: 1,
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
                          _statItem(
                            value: '${_distanceKm > 0 ? _distanceKm.toStringAsFixed(1) : '0.8'} km',
                            label: isTamil ? 'அருகில் vet' : 'NEAREST VET',
                          ),
                          Container(
                            height: 32,
                            width: 1,
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
                          _statItem(
                            value: '21',
                            label: isTamil ? 'தாவரங்கள்' : 'PLANTS',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Main Content Area (White Rounded Card Overlapping Header) ──
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF162319) : const Color(0xFFF4F5F0),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                ),
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Location & Vet Hospital Distance Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isTamil ? 'அருகிலுள்ள கால்நடை மருத்துவமனை' : 'Nearest Vet Location',
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : primaryGreen,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isTamil
                                    ? 'உங்கள் இருப்பிடத்திலிருந்து ${_distanceKm > 0 ? _distanceKm.toStringAsFixed(1) : '0.8'} கி.மீ தொலையில்'
                                    : '${_distanceKm > 0 ? _distanceKm.toStringAsFixed(1) : '0.8'} km distance from your farm location',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  color: isDark ? Colors.white60 : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2EADF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.near_me_rounded, color: primaryGreen, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                '${_distanceKm > 0 ? _distanceKm.toStringAsFixed(1) : '0.8'} km',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: primaryGreen,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Map Container
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        height: 210,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1F3024) : Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: (!_isLocationEnabled)
                            ? Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.location_off_rounded,
                                        color: Colors.amber,
                                        size: 32,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      isTamil
                                          ? 'இருப்பிடம் (Location) ஆஃப் செய்யப்பட்டுள்ளது'
                                          : 'Turn On Phone Location',
                                      style: GoogleFonts.outfit(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? Colors.white : primaryGreen,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      isTamil
                                          ? 'அருகிலுள்ள நிஜ கால்நடை மருத்துவமனையைக் காண உங்கள் போனில் Location-ஐ ஆன் செய்யவும்.'
                                          : 'Turn on location on your phone to view real nearby veterinary hospitals.',
                                      style: GoogleFonts.outfit(
                                        fontSize: 11,
                                        color: isDark ? Colors.white70 : Colors.black54,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 12),
                                    ElevatedButton.icon(
                                      onPressed: () async {
                                        await Geolocator.openLocationSettings();
                                        ref.read(locationProvider.notifier).refreshLocation();
                                      },
                                      icon: const Icon(Icons.location_on_rounded, size: 16),
                                      label: Text(
                                        isTamil ? 'இருப்பிடத்தை ஆன் செய்க (Turn On)' : 'Turn On Location',
                                        style: GoogleFonts.outfit(
                                            fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: primaryGreen,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12)),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 8),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : (_currentPosition == null)
                                ? const Center(child: CircularProgressIndicator(color: primaryGreen))
                                : Stack(
                                    children: [
                                  FlutterMap(
                                    mapController: _mapController,
                                    options: MapOptions(
                                      initialCenter: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                                      initialZoom: 13.5,
                                      interactionOptions: const InteractionOptions(
                                        flags: InteractiveFlag.all,
                                      ),
                                    ),
                                    children: [
                                      TileLayer(
                                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                        userAgentPackageName: 'com.agriguard.livestock',
                                      ),
                                      if (_nearestHospital != null)
                                        PolylineLayer(
                                          polylines: [
                                            Polyline(
                                              points: [
                                                LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                                                LatLng(_nearestHospital!.latitude, _nearestHospital!.longitude)
                                              ],
                                              color: primaryGreen,
                                              strokeWidth: 4.0,
                                            ),
                                          ],
                                        ),
                                      MarkerLayer(
                                        markers: [
                                          // User Location Marker
                                          Marker(
                                            point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                                            width: 44,
                                            height: 44,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: primaryGreen,
                                                shape: BoxShape.circle,
                                                border: Border.all(color: Colors.white, width: 3),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black.withValues(alpha: 0.2),
                                                    blurRadius: 8,
                                                  ),
                                                ],
                                              ),
                                              child: const Icon(Icons.person_pin_circle_rounded,
                                                  color: Colors.white, size: 24),
                                            ),
                                          ),
                                          // All Nearby Vet Hospital Markers
                                          ..._nearbyHospitals.map((h) => Marker(
                                            point: LatLng(h.latitude, h.longitude),
                                            width: h == _nearestHospital ? 44 : 36,
                                            height: h == _nearestHospital ? 44 : 36,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: h == _nearestHospital ? Colors.red[700] : Colors.white,
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: h == _nearestHospital ? Colors.white : Colors.red[300]!,
                                                  width: h == _nearestHospital ? 3 : 2,
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black.withValues(alpha: 0.2),
                                                    blurRadius: 8,
                                                  ),
                                                ],
                                              ),
                                              child: Icon(
                                                Icons.local_hospital_rounded,
                                                color: h == _nearestHospital ? Colors.white : Colors.red[700],
                                                size: h == _nearestHospital ? 22 : 18,
                                              ),
                                            ),
                                          )),
                                        ],
                                      ),
                                    ],
                                  ),

                                  // Map Info Banner Overlay
                                  if (_nearestHospital != null)
                                    Positioned(
                                      bottom: 12,
                                      left: 12,
                                      right: 12,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.95),
                                          borderRadius: BorderRadius.circular(16),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.12),
                                              blurRadius: 10,
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Colors.red[50],
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(Icons.local_hospital_rounded,
                                                  color: Colors.red[700], size: 18),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    isTamil ? _nearestHospital!.tamilName : _nearestHospital!.name,
                                                    style: GoogleFonts.outfit(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w800,
                                                      color: Colors.black87,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  Text(
                                                    '${_nearestHospital!.address} • ${_nearestHospital!.phone}',
                                                    style: GoogleFonts.outfit(
                                                      fontSize: 11,
                                                      color: Colors.black54,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            GestureDetector(
                                              onTap: () => _makePhoneCall(_nearestHospital!.phone),
                                              child: Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: const BoxDecoration(
                                                  color: primaryGreen,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(Icons.phone_rounded,
                                                    color: Colors.white, size: 16),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Farmer Info Card
                    Text(
                      isTamil ? 'விவசாயி விவரங்கள்' : 'Farmer Details',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : primaryGreen,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: isDark
                            ? []
                            : [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                      ),
                      child: Column(
                        children: [
                          _infoTile(
                            context,
                            icon: Icons.phone_rounded,
                            label: isTamil ? 'தொலைபேசி எண்' : 'Phone Number',
                            value: phone,
                          ),
                          Divider(color: Theme.of(context).dividerColor, height: 1, indent: 60),
                          _infoTile(
                            context,
                            icon: Icons.location_city_rounded,
                            label: isTamil ? 'கிராமம் / இடம்' : 'Village / Location',
                            value: '$village, Madurai District',
                          ),
                          Divider(color: Theme.of(context).dividerColor, height: 1, indent: 60),
                          _infoTile(
                            context,
                            icon: Icons.pets_rounded,
                            label: isTamil ? 'கால்நடைகள் எண்ணிக்கை' : 'Livestock Count',
                            value: '$livestock ${isTamil ? 'விலங்குகள்' : 'Animals (Cattle & Goats)'}',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Preferences Card
                    Theme(
                      data: Theme.of(context).copyWith(
                        dividerColor: Colors.transparent,
                        listTileTheme: const ListTileThemeData(dense: true),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: isDark
                              ? []
                              : [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                        ),
                        child: ExpansionTile(
                          iconColor: isDark ? Colors.white : primaryGreen,
                          collapsedIconColor: isDark ? Colors.white70 : primaryGreen,
                          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                          title: Text(
                            isTamil ? 'அமைப்புகள்' : 'App Preferences',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : primaryGreen,
                            ),
                          ),
                          children: [
                            ListTile(
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE2EADF),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                                  color: primaryGreen,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                isTamil ? 'இரவுப் பயன்முறை' : 'Dark Mode',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).textTheme.bodyLarge?.color,
                                ),
                              ),
                              trailing: Switch(
                                value: isDark,
                                activeThumbColor: primaryGreen,
                                activeTrackColor: primaryGreen.withValues(alpha: 0.3),
                                onChanged: (_) => ref.read(themeProvider.notifier).toggleTheme(),
                              ),
                            ),
                            Divider(color: Theme.of(context).dividerColor, height: 1, indent: 60),
                            ListTile(
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE2EADF),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.language_rounded,
                                    color: primaryGreen, size: 20),
                              ),
                              title: Text(
                                isTamil ? 'மொழி' : 'Language',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).textTheme.bodyLarge?.color,
                                ),
                              ),
                              trailing: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE2EADF),
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
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Logout Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          ref.read(authProvider.notifier).logout();
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (_) => const LoginScreen()),
                            (r) => false,
                          );
                        },
                        icon: const Icon(Icons.logout_rounded, size: 20),
                        label: Text(
                          isTamil ? 'வெளியேறு' : 'Log Out',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[700],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statItem({required String value, required String label}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.75),
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _infoTile(BuildContext context,
      {required IconData icon, required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFE2EADF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: const Color(0xFF264633)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.color
                        ?.withValues(alpha: 0.6),
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _langChip(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF264633) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : const Color(0xFF264633),
          ),
        ),
      ),
    );
  }
}
