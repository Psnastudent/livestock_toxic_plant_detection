import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/plant.dart';
import '../data/vet_hospitals.dart';
import '../providers/language_provider.dart';

class PlantDetailsScreen extends ConsumerStatefulWidget {
  final Plant plant;
  final bool showVetButton;

  const PlantDetailsScreen({
    super.key,
    required this.plant,
    this.showVetButton = false,
  });

  @override
  ConsumerState<PlantDetailsScreen> createState() => _PlantDetailsScreenState();
}

class _PlantDetailsScreenState extends ConsumerState<PlantDetailsScreen> {
  Position? _livePosition;
  StreamSubscription<Position>? _positionStream;
  final MapController _mapController = MapController();
  VetHospital? _nearestHospital;

  @override
  void initState() {
    super.initState();
    if (widget.showVetButton) _startLiveLocation();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  VetHospital _findNearest(double lat, double lng) {
    VetHospital nearest = vetHospitals[0];
    double minD = double.infinity;
    for (final h in vetHospitals) {
      final d = sqrt(pow(h.latitude - lat, 2) + pow(h.longitude - lng, 2));
      if (d < minD) { minD = d; nearest = h; }
    }
    return nearest;
  }

  Future<void> _startLiveLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) return;
    }
    if (perm == LocationPermission.deniedForever) return;

    final initial = await Geolocator.getCurrentPosition();
    setState(() {
      _livePosition = initial;
      _nearestHospital = _findNearest(initial.latitude, initial.longitude);
    });
    _mapController.move(LatLng(initial.latitude, initial.longitude), 14.0);

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5),
    ).listen((pos) {
      if (mounted) {
        setState(() {
          _livePosition = pos;
          _nearestHospital = _findNearest(pos.latitude, pos.longitude);
        });
        _mapController.move(LatLng(pos.latitude, pos.longitude), 14.0);
      }
    });
  }

  Future<void> _makePhoneCall(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone.replaceAll(' ', ''));
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final plant = widget.plant;
    final isHarmful = plant.isHarmful;
    final lang = ref.watch(languageProvider);
    final isTamil = lang == AppLanguage.tamil;
    final tr = ref.read(translationProvider);
    String t(String key) => tr[key]?[isTamil ? 'tamil' : 'english'] ?? key;

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Hero image
          SliverAppBar(
            expandedHeight: 340,
            pinned: true,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
                ),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isHarmful ? Icons.warning_rounded : Icons.favorite_border_rounded,
                    color: isHarmful ? Colors.redAccent : Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: 'plant_image_${plant.plantId}',
                    child: Image.asset(
                      plant.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: const Color(0xFFE8F5E9),
                        child: Icon(Icons.eco_rounded, size: 60,
                            color: const Color(0xFF2E7D32).withValues(alpha: 0.3)),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0, left: 0, right: 0, height: 100,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.5)],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 16, left: 24,
                    child: Row(
                      children: [
                        const Icon(Icons.location_on_rounded, size: 14, color: Colors.white70),
                        const SizedBox(width: 4),
                        Text(plant.region,
                            style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white70)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isTamil ? plant.tamilName : plant.englishName,
                      style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w800,
                          color: Theme.of(context).textTheme.bodyLarge?.color)),
                  const SizedBox(height: 4),
                  Text(plant.scientificName,
                      style: GoogleFonts.outfit(fontSize: 15, fontStyle: FontStyle.italic,
                          color: const Color(0xFF2E7D32))),
                  const SizedBox(height: 20),

                  // Stats row
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardTheme.color,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10, offset: const Offset(0, 3))],
                    ),
                    child: Row(
                      children: [
                        _stat(Icons.warning_amber_rounded,
                            isHarmful ? Colors.red[700]! : Colors.green[700]!,
                            isHarmful ? t('toxic') : t('safe'), t('toxicity_level'), context),
                        Container(width: 1, height: 40, color: Theme.of(context).dividerColor),
                        _stat(Icons.speed_rounded, Colors.orange[700]!,
                            t(plant.susceptibilityLevel.name), t('susceptibility'), context),
                        Container(width: 1, height: 40, color: Theme.of(context).dividerColor),
                        _stat(Icons.restaurant_rounded,
                            plant.isEatable ? Colors.green[700]! : Colors.grey[600]!,
                            plant.isEatable ? t('edible') : t('not_fodder'), t('edibility'), context),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Warning
                  if (isHarmful) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.red[400], size: 26),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(t('toxicity_warning'),
                                style: GoogleFonts.outfit(
                                    color: Theme.of(context).textTheme.bodyLarge?.color,
                                    fontSize: 13, height: 1.4)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Description
                  Text(t('about_plant'),
                      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700,
                          color: Theme.of(context).textTheme.bodyLarge?.color)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardTheme.color,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10, offset: const Offset(0, 3))],
                    ),
                    child: Text(
                      isTamil ? plant.tamilDescription : plant.description,
                      style: GoogleFonts.outfit(
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                          fontSize: 14, height: 1.7),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Vet section
                  if (widget.showVetButton) ...[
                    Text('🏥  ${t('nearest_vet')}',
                        style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700,
                            color: Theme.of(context).textTheme.bodyLarge?.color)),
                    const SizedBox(height: 12),
                    _buildVetSection(context, isTamil, t),
                    const SizedBox(height: 28),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(IconData icon, Color iconColor, String value, String label, BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(height: 6),
          Text(value,
              style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700,
                  color: Theme.of(context).textTheme.bodyLarge?.color),
              textAlign: TextAlign.center),
          const SizedBox(height: 2),
          Text(label,
              style: GoogleFonts.outfit(fontSize: 10,
                  color: Theme.of(context).textTheme.bodySmall?.color),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildVetSection(BuildContext context, bool isTamil, String Function(String) t) {
    final center = _livePosition != null
        ? LatLng(_livePosition!.latitude, _livePosition!.longitude)
        : const LatLng(11.0168, 76.9558);
    final hospital = _nearestHospital ?? vetHospitals[2];
    final vetLoc = LatLng(hospital.latitude, hospital.longitude);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.local_hospital_rounded,
                      color: Color(0xFF2E7D32), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(isTamil ? hospital.tamilName : hospital.name,
                          style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700,
                              color: Theme.of(context).textTheme.bodyLarge?.color),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Row(children: [
                        const Icon(Icons.location_on_outlined, size: 12, color: Color(0xFF2E7D32)),
                        const SizedBox(width: 4),
                        Expanded(child: Text(hospital.address,
                            style: GoogleFonts.outfit(fontSize: 11,
                                color: Theme.of(context).textTheme.bodyMedium?.color),
                            maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ]),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () => _makePhoneCall(hospital.phone),
                        child: Row(children: [
                          Icon(Icons.phone_rounded, size: 12, color: Colors.green[700]),
                          const SizedBox(width: 4),
                          Text(hospital.phone,
                              style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600,
                                  color: Colors.green[700],
                                  decoration: TextDecoration.underline)),
                        ]),
                      ),
                      const SizedBox(height: 6),
                      Row(children: [
                        Icon(Icons.circle, size: 8,
                            color: _livePosition != null ? Colors.green : Colors.amber),
                        const SizedBox(width: 6),
                        Text(_livePosition != null ? t('live_location') : t('acquiring_location'),
                            style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600,
                                color: _livePosition != null ? Colors.green : Colors.amber)),
                      ]),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => _makePhoneCall(hospital.phone),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(
                          color: const Color(0xFF2E7D32).withValues(alpha: 0.3),
                          blurRadius: 8, offset: const Offset(0, 3))],
                    ),
                    child: const Icon(Icons.phone_rounded, color: Colors.white, size: 24),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Theme.of(context).dividerColor),
          SizedBox(
            height: 220,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(initialCenter: center, initialZoom: 14.0),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.livestock_toxic_plant_detection',
                  ),
                  MarkerLayer(markers: [
                    if (_livePosition != null)
                      Marker(point: center, width: 24, height: 24,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.blue, shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [BoxShadow(color: Colors.blue.withValues(alpha: 0.4),
                                  blurRadius: 12, spreadRadius: 4)],
                            ),
                          )),
                    Marker(point: vetLoc, width: 40, height: 40,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white, shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 6)],
                          ),
                          child: const Icon(Icons.local_hospital_rounded,
                              color: Color(0xFFD32F2F), size: 24),
                        )),
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
