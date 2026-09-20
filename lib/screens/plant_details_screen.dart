import 'dart:io';
import '../widgets/glass_card.dart';
import '../widgets/themed_background.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/plant.dart';
import '../data/vet_hospitals.dart';
import '../providers/language_provider.dart';
import '../providers/location_provider.dart';

class PlantDetailsScreen extends ConsumerStatefulWidget {
  final Plant plant;
  final bool showVetButton;
  final String? heroTag;

  const PlantDetailsScreen({
    super.key,
    required this.plant,
    this.showVetButton = false,
    this.heroTag,
  });

  @override
  ConsumerState<PlantDetailsScreen> createState() => _PlantDetailsScreenState();
}

class _PlantDetailsScreenState extends ConsumerState<PlantDetailsScreen> {
  final MapController _mapController = MapController();
  bool _mapMoved = false;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterTts _flutterTts = FlutterTts();
  bool isPlaying = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) setState(() => isPlaying = false);
    });
  }

  @override
  void dispose() {
    _audioPlayer.stop();
    _flutterTts.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _makePhoneCall(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone.replaceAll(' ', ''));
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _speakTamil(Plant plant) async {
    if (isPlaying) {
      await _audioPlayer.stop();
      await _flutterTts.stop();
      if (mounted) setState(() => isPlaying = false);
      return;
    }

    if (mounted) setState(() => isPlaying = true);

    final isTamil = ref.read(languageProvider) == AppLanguage.tamil;

    String textToSpeak = isTamil
      ? (plant.isHarmful 
          ? "எச்சரிக்கை! ${plant.tamilName} மாடுகளுக்கு ஆபத்தானது. அறிகுறிகள்: ${plant.tamilSymptoms} முதல் உதவி: ${plant.tamilFirstAid} தயவுசெய்து உடனடியாக அருகில் உள்ள கால்நடை மருத்துவமனைக்கு செல்லவும்."
          : "${plant.tamilName} ஒரு பாதுகாப்பான தாவரம். இது மாடுகளுக்கு நல்ல தீவனம்.")
      : (plant.isHarmful
          ? "Warning! ${plant.englishName} is toxic to livestock. Symptoms include: ${plant.symptoms}. First aid: ${plant.firstAid}. Please rush to the nearest veterinary hospital."
          : "${plant.englishName} is a safe plant. It is good fodder for livestock.");

    final String apiKey = "6ee6552afd399b1c4d8785cb726113681965aaf60f51f669f4d1ca7226db81bf";
    final String voiceId = "pNInz6obpgDQGcFmaJcg"; // Adam - male voice
    final String url = "https://api.elevenlabs.io/v1/text-to-speech/$voiceId";

    bool playedWithElevenLabs = false;

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'xi-api-key': apiKey,
          'Content-Type': 'application/json',
          'Accept': 'audio/mpeg',
        },
        body: json.encode({
          "text": textToSpeak,
          "model_id": "eleven_multilingual_v2",
          "voice_settings": {
            "stability": 0.5,
            "similarity_boost": 0.75
          }
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        final tempDir = Directory.systemTemp;
        final tempFile = File('${tempDir.path}/elevenlabs_tts.mp3');
        await tempFile.writeAsBytes(response.bodyBytes);

        await _audioPlayer.stop();
        await _audioPlayer.play(DeviceFileSource(tempFile.path));
        playedWithElevenLabs = true;
      } else {
        debugPrint("ElevenLabs API non-200: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("ElevenLabs TTS exception: $e");
    }

    if (!playedWithElevenLabs) {
      try {
        await _flutterTts.setLanguage(isTamil ? "ta-IN" : "en-US");
        await _flutterTts.setPitch(1.0);
        await _flutterTts.setSpeechRate(0.45);
        _flutterTts.setCompletionHandler(() {
          if (mounted) setState(() => isPlaying = false);
        });
        _flutterTts.setErrorHandler((msg) {
          if (mounted) setState(() => isPlaying = false);
        });
        await _flutterTts.speak(textToSpeak);
      } catch (e) {
        debugPrint("FlutterTts fallback error: $e");
        if (mounted) setState(() => isPlaying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final plant = widget.plant;
    final isHarmful = plant.isHarmful;
    final lang = ref.watch(languageProvider);
    final isTamil = lang == AppLanguage.tamil;
    final tr = ref.read(translationProvider);
    String t(String key) => tr[key]?[isTamil ? 'tamil' : 'english'] ?? key;

    // Read centralized location state
    final locState = ref.watch(locationProvider);
    final livePosition = locState.position;
    final isLocationEnabled = locState.isLocationEnabled;
    final nearestHospital = locState.nearestHospital;
    final nearbyHospitals = locState.nearbyHospitals;

    // Move map to user's position once when it becomes available
    if (widget.showVetButton && livePosition != null && !_mapMoved) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _mapController.move(
            LatLng(livePosition.latitude, livePosition.longitude),
            14.0,
          );
          _mapMoved = true;
        }
      });
    }

    return ThemedBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Hero image
            SliverAppBar(
              expandedHeight: 340,
              pinned: true,
              backgroundColor: Colors.transparent,
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
                child: GestureDetector(
                  onTap: () => _speakTamil(plant),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isPlaying ? Colors.blue : Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isPlaying ? Icons.stop_circle_rounded : Icons.volume_up_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        Text(isTamil ? 'தமிழ்' : 'EN', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
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
                    tag: widget.heroTag ?? 'plant_image_${plant.plantId}',
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
                    bottom: 16, left: 24, right: 24,
                    child: Row(
                      children: [
                        const Icon(Icons.location_on_rounded, size: 14, color: Colors.white70),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(plant.region,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white70)),
                        ),
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

                  GlassCard(
                    borderRadius: 20,
                    padding: const EdgeInsets.all(16),
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

                  // Warning Message
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
                            child: Text(isTamil ? plant.tamilWarningMessage : plant.warningMessage,
                                style: GoogleFonts.outfit(
                                    color: Theme.of(context).textTheme.bodyLarge?.color,
                                    fontSize: 14, fontWeight: FontWeight.w600, height: 1.4)),
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
                  GlassCard(
                    borderRadius: 20,
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      isTamil ? plant.tamilDescription : plant.description,
                      style: GoogleFonts.outfit(
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                          fontSize: 14, height: 1.7),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Hosts Affected & Onset
                  GlassCard(
                    borderRadius: 20,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.pets_rounded, color: Colors.brown, size: 20),
                            const SizedBox(width: 10),
                            Expanded(child: Text(isTamil ? 'பாதிக்கப்படும் விலங்குகள் (Hosts Affected):' : 'Hosts Affected:', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color))),
                          ]
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 30, top: 4, bottom: 12),
                          child: Text(isTamil ? plant.tamilHostsAffected : plant.hostsAffected, style: GoogleFonts.outfit(fontSize: 14, height: 1.4, color: Theme.of(context).textTheme.bodyMedium?.color)),
                        ),
                        Divider(height: 1, color: Theme.of(context).dividerColor),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.access_time_rounded, color: Colors.blueGrey, size: 20),
                            const SizedBox(width: 10),
                            Expanded(child: Text(isTamil ? 'அறிகுறிகள் தோன்றும் நேரம் (Onset):' : 'Time of Symptoms Onset:', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color))),
                          ]
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 30, top: 4),
                          child: Text(isTamil ? plant.tamilOnsetOfSymptoms : plant.onsetOfSymptoms, style: GoogleFonts.outfit(fontSize: 14, height: 1.4, color: Theme.of(context).textTheme.bodyMedium?.color)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  if (isHarmful) ...[
                    Text(isTamil ? 'அறிகுறிகள் (Symptoms)' : 'Symptoms',
                        style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700,
                            color: Theme.of(context).textTheme.bodyLarge?.color)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.sick_rounded, color: Colors.orange, size: 24),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(isTamil ? plant.tamilSymptoms : plant.symptoms,
                                    style: GoogleFonts.outfit(fontSize: 14, height: 1.5,
                                        color: Theme.of(context).textTheme.bodyLarge?.color)),
                              ),
                            ],
                          ),
                          if (plant.symptomsImageUrl.isNotEmpty) ...[
                             const SizedBox(height: 16),
                             ClipRRect(
                               borderRadius: BorderRadius.circular(12),
                               child: Image.network(
                                 plant.symptomsImageUrl,
                                 width: double.infinity,
                                 height: 180,
                                 fit: BoxFit.cover,
                                 errorBuilder: (ctx, err, stack) => const SizedBox(),
                               ),
                             )
                          ]
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    Text(isTamil ? 'முதல் உதவி (First Aid)' : 'First Aid',
                        style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700,
                            color: Theme.of(context).textTheme.bodyLarge?.color)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.medical_services_rounded, color: Colors.blue, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(isTamil ? plant.tamilFirstAid : plant.firstAid,
                                style: GoogleFonts.outfit(fontSize: 14, height: 1.5,
                                    color: Theme.of(context).textTheme.bodyLarge?.color)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    Text(isTamil ? 'கால்நடை மருத்துவ சிகிச்சை (Veterinary Treatment)' : 'Veterinary Treatment',
                        style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700,
                            color: Theme.of(context).textTheme.bodyLarge?.color)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.teal.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.healing_rounded, color: Colors.teal, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(isTamil ? plant.tamilVeterinaryTreatment : plant.veterinaryTreatment,
                                style: GoogleFonts.outfit(fontSize: 14, height: 1.5,
                                    color: Theme.of(context).textTheme.bodyLarge?.color)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],

                  // Vet section
                  if (widget.showVetButton) ...[
                    Row(
                      children: [
                        const Icon(Icons.local_hospital_rounded, color: Color(0xFF2E7D32), size: 22),
                        const SizedBox(width: 8),
                        Text(
                          t('nearest_vet'),
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildVetSection(context, isTamil, t, locState: locState),
                    const SizedBox(height: 28),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    ));
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
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildVetSection(BuildContext context, bool isTamil, String Function(String) t, {required LocationState locState}) {
    final livePosition = locState.position;
    final isLocationEnabled = locState.isLocationEnabled;
    final nearestHospital = locState.nearestHospital;
    final nearbyHospitals = locState.nearbyHospitals;

    if (!isLocationEnabled) {
      return GlassCard(
        borderRadius: 20,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.location_off_rounded, color: Colors.amber, size: 32),
            ),
            const SizedBox(height: 12),
            Text(
              isTamil ? 'இருப்பிடம் (Location) ஆஃப் செய்யப்பட்டுள்ளது' : 'Turn On Phone Location',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              isTamil
                  ? 'அருகிலுள்ள நிஜ கால்நடை மருத்துவமனையைக் காண உங்கள் போனில் Location-ஐ ஆன் செய்யவும்.'
                  : 'Turn on location on your phone to view real nearby veterinary hospitals.',
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: () async {
                await Geolocator.openLocationSettings();
                ref.read(locationProvider.notifier).refreshLocation();
              },
              icon: const Icon(Icons.location_on_rounded, size: 18),
              label: Text(
                isTamil ? 'இருப்பிடத்தை ஆன் செய்க (Turn On)' : 'Turn On Location',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
            ),
          ],
        ),
      );
    }

    if (livePosition == null) {
      return GlassCard(
        borderRadius: 20,
        padding: const EdgeInsets.all(32),
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFF2E7D32)),
        ),
      );
    }

    final center = LatLng(livePosition.latitude, livePosition.longitude);
    final hospital = nearestHospital ?? vetHospitals[0];

    return GlassCard(
      borderRadius: 20,
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
                        const Icon(Icons.circle, size: 8, color: Colors.green),
                        const SizedBox(width: 6),
                        Text(t('live_location'),
                            style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600,
                                color: Colors.green)),
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
                    Marker(
                      point: center,
                      width: 24,
                      height: 24,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(color: Colors.blue.withValues(alpha: 0.4), blurRadius: 12, spreadRadius: 4)
                          ],
                        ),
                      ),
                    ),
                    // All nearby vet hospital markers from central provider
                    ...nearbyHospitals.map((h) => Marker(
                      point: LatLng(h.latitude, h.longitude),
                      width: h == hospital ? 48 : 36,
                      height: h == hospital ? 48 : 36,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: h == hospital ? Colors.green : Colors.transparent,
                            width: h == hospital ? 2 : 0,
                          ),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 6)],
                        ),
                        child: Icon(
                          Icons.local_hospital_rounded,
                          color: const Color(0xFFD32F2F),
                          size: h == hospital ? 28 : 20,
                        ),
                      ),
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

