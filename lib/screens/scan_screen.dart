import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../models/plant.dart';
import '../data/mock_plants.dart';
import '../providers/language_provider.dart';
import 'plant_details_screen.dart';

class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen>
    with SingleTickerProviderStateMixin {
  File? _imageFile;
  bool _isScanning = false;
  late AnimationController _pulseController;

  Interpreter? _interpreter;
  List<String>? _labels;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _loadModel();
  }

  Future<void> _loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/model/plant_classifier.tflite');
      final labelsData = await rootBundle.loadString('assets/model/labels.txt');
      _labels = labelsData.split('\n').where((s) => s.trim().isNotEmpty).toList();
      debugPrint('Model and ${_labels?.length} labels loaded successfully.');
    } catch (e) {
      debugPrint('Error loading model: $e');
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _interpreter?.close();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() => _imageFile = File(pickedFile.path));
        _runInference();
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> _runInference() async {
    if (_imageFile == null) return;
    
    // Check if model loaded
    if (_interpreter == null || _labels == null) {
      debugPrint("Model not loaded yet!");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wait for ML model to load...')),
      );
      return;
    }

    setState(() => _isScanning = true);

    try {
      // 1. Load and decode image
      final bytes = await _imageFile!.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) throw Exception("Failed to decode image");

      // 2. Resize to 224x224
      final resized = img.copyResize(image, width: 224, height: 224);

      // 3. Create input tensor [1, 224, 224, 3] Float32
      // The model contains a Rescaling layer that maps [0, 255] to [-1, 1], so we feed [0, 255].
      var input = List.generate(1, (i) => 
        List.generate(224, (y) => 
          List.generate(224, (x) => 
            List.generate(3, (c) => 0.0)
          )
        )
      );

      for (int y = 0; y < 224; y++) {
        for (int x = 0; x < 224; x++) {
          final pixel = resized.getPixel(x, y);
          input[0][y][x][0] = pixel.r.toDouble();
          input[0][y][x][1] = pixel.g.toDouble();
          input[0][y][x][2] = pixel.b.toDouble();
        }
      }

      // 4. Create output tensor
      var output = List.generate(1, (i) => List.filled(_labels!.length, 0.0));

      // 5. Run inference
      _interpreter!.run(input, output);
      final scores = output[0];

      // 6. Find max score
      int maxIdx = 0;
      double maxScore = scores[0];
      for (int i = 1; i < scores.length; i++) {
        if (scores[i] > maxScore) {
          maxScore = scores[i];
          maxIdx = i;
        }
      }

      final predictedLabel = _labels![maxIdx].trim();
      debugPrint("Prediction: $predictedLabel ($maxScore)");

      // 7. Find matching plant
      // Labels are 'Lantana_camara' and 'Parthenium_hysterophorus'
      Plant? foundPlant;
      for (final p in mockPlants) {
        if (p.scientificName.replaceAll(' ', '_') == predictedLabel) {
          foundPlant = p;
          break;
        }
      }

      // Fallback if somehow not found
      foundPlant ??= mockPlants.firstWhere((p) => p.plantId == 'p01');

      // Add a slight delay just for the UI scanning effect 
      await Future.delayed(const Duration(milliseconds: 1500));

      if (mounted) {
        _navigateToResults(foundPlant);
      }

    } catch (e) {
      debugPrint("Inference error: $e");
      setState(() => _isScanning = false);
    }
  }

  void _navigateToResults(Plant plant) {
    if (!mounted) return;
    setState(() => _isScanning = false);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlantDetailsScreen(plant: plant, showVetButton: plant.isHarmful),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final isTamil = lang == AppLanguage.tamil;
    final tr = ref.read(translationProvider);
    String t(String key) => tr[key]?[isTamil ? 'tamil' : 'english'] ?? key;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(t('identify_plant'),
                  style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w800,
                      color: Theme.of(context).textTheme.bodyLarge?.color)),
            ),
            const Spacer(flex: 1),

            // Viewfinder
            if (_imageFile != null)
              Container(
                height: 340,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  image: DecorationImage(image: FileImage(_imageFile!), fit: BoxFit.cover),
                ),
                child: _isScanning
                    ? Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          color: Colors.black.withValues(alpha: 0.4),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedBuilder(
                                animation: _pulseController,
                                builder: (_, child) => Transform.scale(
                                    scale: 0.8 + (_pulseController.value * 0.3),
                                    child: child),
                                child: Container(
                                  width: 80, height: 80,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 3),
                                  ),
                                  child: const Icon(Icons.document_scanner_rounded,
                                      color: Colors.white, size: 36),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(t('scanning'),
                                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      )
                    : null,
              )
            else
              Container(
                height: 320,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (_, child) => Transform.scale(
                          scale: 0.9 + (_pulseController.value * 0.1),
                          child: Opacity(opacity: 0.5 + (_pulseController.value * 0.5), child: child)),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.document_scanner_rounded,
                            size: 56, color: Color(0xFF2E7D32)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(t('position_plant'),
                        style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600,
                            color: Theme.of(context).textTheme.bodyLarge?.color)),
                    const SizedBox(height: 8),
                    Text(
                      isTamil ? 'லந்தானா & பார்த்தீனியம் கண்டறிதல்' : 'Trained for Lantana & Parthenium',
                      style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF2E7D32), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),

            const Spacer(flex: 1),

            // Buttons
            if (!_isScanning)
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _pickImage(ImageSource.camera),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E7D32),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [BoxShadow(
                              color: const Color(0xFF2E7D32).withValues(alpha: 0.3),
                              blurRadius: 12, offset: const Offset(0, 4))],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Text(t('take_photo'),
                                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _pickImage(ImageSource.gallery),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.photo_library_rounded, color: Color(0xFF2E7D32), size: 20),
                            const SizedBox(width: 8),
                            Text(t('gallery'),
                                style: GoogleFonts.outfit(color: const Color(0xFF2E7D32),
                                    fontWeight: FontWeight.w700, fontSize: 15)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}
