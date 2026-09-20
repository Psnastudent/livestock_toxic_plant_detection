import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';

import '../models/plant.dart';
import '../services/gemini_plant_service.dart';
import '../providers/language_provider.dart';
import 'plant_details_screen.dart';
import 'plant_not_recognized_screen.dart';

class ScanScreen extends ConsumerStatefulWidget {
  final File? initialImageFile;
  const ScanScreen({super.key, this.initialImageFile});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen>
    with SingleTickerProviderStateMixin {
  File? _imageFile;
  bool _isScanning = false;
  String? _errorMessage;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final GeminiPlantService _geminiService = GeminiPlantService();

  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isFlashOn = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );
    _pulseController.repeat(reverse: true);

    if (widget.initialImageFile != null) {
      _imageFile = widget.initialImageFile;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _runGeminiIdentification();
      });
    } else {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        _cameraController = CameraController(
          _cameras![0],
          ResolutionPreset.high,
          enableAudio: false,
        );
        await _cameraController!.initialize();
        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
          });
        }
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
          _errorMessage = null;
        });
        _runGeminiIdentification();
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> _runGeminiIdentification() async {
    if (_imageFile == null) return;

    setState(() {
      _isScanning = true;
      _errorMessage = null;
    });

    try {
      final result = await _geminiService.identifyPlant(_imageFile!);

      if (!mounted) return;

      if (result.isSuccess) {
        setState(() => _isScanning = false);
        if (result.isFallback) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Identified via trained local plant classifier model.'),
              backgroundColor: Color(0xFF2E7D32),
              duration: Duration(seconds: 3),
            ),
          );
        }
        _navigateToResults(result.plant!);
        return;
      }

      if (result.isNotRecognized) {
        setState(() => _isScanning = false);
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PlantNotRecognizedScreen(
              imageFile: _imageFile!,
              result: result,
            ),
          ),
        );
        return;
      }

      if (result.isError) {
        setState(() {
          _isScanning = false;
          _errorMessage = result.errorMessage;
        });
        return;
      }
    } catch (e) {
      debugPrint("Gemini identification error: $e");
      if (mounted) {
        setState(() {
          _isScanning = false;
          _errorMessage = 'An unexpected error occurred. Please try again.';
        });
      }
    }
  }

  void _navigateToResults(Plant plant) {
    if (!mounted) return;
    if (Navigator.canPop(context)) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PlantDetailsScreen(plant: plant, showVetButton: plant.isHarmful),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlantDetailsScreen(plant: plant, showVetButton: plant.isHarmful),
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
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background layer: Camera Preview or Selected Image
          if (_imageFile != null)
            Positioned.fill(
              child: Image.file(_imageFile!, fit: BoxFit.cover),
            )
          else if (_isCameraInitialized && _cameraController != null)
            Positioned.fill(
              child: CameraPreview(_cameraController!),
            )
          else
            const Center(child: CircularProgressIndicator(color: Colors.white)),
          
          // Shading overlay when scanning
          if (_isScanning)
            Positioned.fill(
              child: Container(color: Colors.black.withValues(alpha: 0.5)),
            ),
          
          // Viewfinder corners (Center)
          Center(
            child: CustomPaint(
              size: const Size(260, 260),
              painter: ViewfinderPainter(),
            ),
          ),
          
          // Center scanning animation or dot
          Center(
            child: _isScanning 
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                     // The pulsing icon
                     RepaintBoundary(
                        child: AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (_, child) => Transform.scale(
                              scale: 0.8 + (_pulseAnimation.value * 0.3),
                              child: child),
                          child: Container(
                            width: 60, height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 3),
                            ),
                            child: const Icon(Icons.document_scanner_rounded, color: Colors.white, size: 28),
                          ),
                        ),
                     ),
                     const SizedBox(height: 20),
                     Text(t('scanning'),
                         style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                     const SizedBox(height: 8),
                     Text(
                       isTamil ? 'Gemini AI பகுப்பாய்வு செய்கிறது...' : 'Gemini AI analyzing...',
                       style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13),
                     ),
                  ],
                )
              : Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.8),
                    shape: BoxShape.circle,
                  ),
                ),
          ),

          // Error message floating
          if (_errorMessage != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 80,
              left: 20, right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.redAccent),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(_errorMessage!,
                          style: GoogleFonts.outfit(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
              ),
            ),

          // Top floating back button
          if (Navigator.canPop(context))
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              child: GestureDetector(
                onTap: () {
                  if (_imageFile != null && widget.initialImageFile == null) {
                    setState(() {
                      _imageFile = null;
                      _isScanning = false;
                      _errorMessage = null;
                    });
                  } else {
                    Navigator.pop(context);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 2))
                    ],
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black, size: 20),
                ),
              ),
            ),
          
          // Bottom controls
          if (!_isScanning && _imageFile == null)
            Positioned(
              bottom: 40,
              left: 0, right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Gallery Button
                  IconButton(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_rounded, color: Colors.white, size: 30),
                  ),
                  
                  // Shutter Button
                  GestureDetector(
                    onTap: () async {
                      if (!_isCameraInitialized || _cameraController == null) return;
                      try {
                        final xFile = await _cameraController!.takePicture();
                        setState(() {
                          _imageFile = File(xFile.path);
                        });
                        _runGeminiIdentification();
                      } catch (e) {
                        debugPrint("Error taking picture: $e");
                      }
                    },
                    child: Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        color: Colors.transparent,
                      ),
                      child: Center(
                        child: Container(
                          width: 64, height: 64,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  // Flash Toggle
                  IconButton(
                    onPressed: () async {
                      if (!_isCameraInitialized || _cameraController == null) return;
                      _isFlashOn = !_isFlashOn;
                      await _cameraController!.setFlashMode(
                        _isFlashOn ? FlashMode.torch : FlashMode.off
                      );
                      setState(() {});
                    },
                    icon: Icon(
                      _isFlashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded, 
                      color: Colors.white, size: 30
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class ViewfinderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final double length = 40; // length of the corner segments
    final double r = 24; // border radius

    // Top Left
    var path = Path()
      ..moveTo(0, length)
      ..lineTo(0, r)
      ..arcToPoint(Offset(r, 0), radius: Radius.circular(r))
      ..lineTo(length, 0);
    canvas.drawPath(path, paint);

    // Top Right
    path = Path()
      ..moveTo(size.width - length, 0)
      ..lineTo(size.width - r, 0)
      ..arcToPoint(Offset(size.width, r), radius: Radius.circular(r))
      ..lineTo(size.width, length);
    canvas.drawPath(path, paint);

    // Bottom Left
    path = Path()
      ..moveTo(0, size.height - length)
      ..lineTo(0, size.height - r)
      ..arcToPoint(Offset(r, size.height), radius: Radius.circular(r), clockwise: false)
      ..lineTo(length, size.height);
    canvas.drawPath(path, paint);

    // Bottom Right
    path = Path()
      ..moveTo(size.width - length, size.height)
      ..lineTo(size.width - r, size.height)
      ..arcToPoint(Offset(size.width, size.height - r), radius: Radius.circular(r), clockwise: false)
      ..lineTo(size.width, size.height - length);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
