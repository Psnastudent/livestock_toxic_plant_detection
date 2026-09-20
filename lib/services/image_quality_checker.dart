import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Result of an image quality check.
class ImageQualityResult {
  final bool isAcceptable;
  final double blurScore;      // Higher = sharper. Threshold ~100
  final double brightnessScore; // 0-255 average brightness
  final int width;
  final int height;
  final String? issue;         // Human-readable issue description
  final String? issueKey;      // Translation key for the issue

  const ImageQualityResult({
    required this.isAcceptable,
    this.blurScore = 0,
    this.brightnessScore = 128,
    this.width = 0,
    this.height = 0,
    this.issue,
    this.issueKey,
  });

  factory ImageQualityResult.acceptable({
    double blurScore = 200,
    double brightnessScore = 128,
    int width = 224,
    int height = 224,
  }) {
    return ImageQualityResult(
      isAcceptable: true,
      blurScore: blurScore,
      brightnessScore: brightnessScore,
      width: width,
      height: height,
    );
  }

  factory ImageQualityResult.tooDark({
    double blurScore = 200,
    double brightnessScore = 30,
  }) {
    return ImageQualityResult(
      isAcceptable: false,
      blurScore: blurScore,
      brightnessScore: brightnessScore,
      issue: 'Photo is too dark. Please try with better lighting.',
      issueKey: 'quality_too_dark',
    );
  }

  factory ImageQualityResult.tooBlurry({
    double blurScore = 20,
    double brightnessScore = 128,
  }) {
    return ImageQualityResult(
      isAcceptable: false,
      blurScore: blurScore,
      brightnessScore: brightnessScore,
      issue: 'Photo is too blurry. Please hold the camera steady and try again.',
      issueKey: 'quality_too_blurry',
    );
  }

  factory ImageQualityResult.tooSmall({int width = 50, int height = 50}) {
    return ImageQualityResult(
      isAcceptable: false,
      width: width,
      height: height,
      issue: 'Photo resolution is too low. Please take a closer photo.',
      issueKey: 'quality_too_small',
    );
  }
}

/// Checks image quality before sending to AI for plant identification.
///
/// Detects:
/// - Blurry images (Laplacian variance)
/// - Too dark images (average brightness)
/// - Too small images (resolution)
class ImageQualityChecker {
  /// Minimum Laplacian variance to consider image "sharp enough".
  static const double _blurThreshold = 50.0;

  /// Minimum average brightness (0-255).
  static const double _darknessThreshold = 40.0;

  /// Minimum image dimension in pixels.
  static const int _minDimension = 100;

  /// Check the quality of an image file.
  ///
  /// Returns [ImageQualityResult] with details about the image quality.
  /// Runs in an isolate to avoid blocking the UI thread.
  static Future<ImageQualityResult> check(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      // Run heavy computation in a separate isolate
      return await compute(_analyzeImage, bytes);
    } catch (e) {
      debugPrint('ImageQualityChecker error: $e');
      // If we can't check, let it through — the AI will handle it
      return ImageQualityResult.acceptable();
    }
  }

  /// Analyze image quality (runs in isolate).
  static ImageQualityResult _analyzeImage(Uint8List bytes) {
    final image = img.decodeImage(bytes);
    if (image == null) {
      return ImageQualityResult.acceptable(); // Can't decode? Let AI handle it
    }

    final width = image.width;
    final height = image.height;

    // 1. Check resolution
    if (width < _minDimension || height < _minDimension) {
      return ImageQualityResult.tooSmall(width: width, height: height);
    }

    // 2. Resize for faster analysis (analysis doesn't need full resolution)
    final analysisSize = 224;
    final resized = img.copyResize(image, width: analysisSize, height: analysisSize);

    // 3. Calculate brightness
    double totalBrightness = 0;
    final pixelCount = analysisSize * analysisSize;

    for (int y = 0; y < analysisSize; y++) {
      for (int x = 0; x < analysisSize; x++) {
        final pixel = resized.getPixel(x, y);
        // Luminance formula: 0.299R + 0.587G + 0.114B
        totalBrightness += 0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b;
      }
    }
    final avgBrightness = totalBrightness / pixelCount;

    if (avgBrightness < _darknessThreshold) {
      return ImageQualityResult.tooDark(
        brightnessScore: avgBrightness,
      );
    }

    // 4. Calculate blur score using Laplacian variance
    //    The Laplacian highlights edges. Sharp images have high variance.
    final blurScore = _computeLaplacianVariance(resized, analysisSize);

    if (blurScore < _blurThreshold) {
      return ImageQualityResult.tooBlurry(
        blurScore: blurScore,
        brightnessScore: avgBrightness,
      );
    }

    return ImageQualityResult(
      isAcceptable: true,
      blurScore: blurScore,
      brightnessScore: avgBrightness,
      width: width,
      height: height,
    );
  }

  /// Compute Laplacian variance as a measure of image sharpness.
  ///
  /// Applies a simplified Laplacian kernel and returns the variance.
  /// Higher values = sharper image.
  static double _computeLaplacianVariance(img.Image image, int size) {
    // Convert to grayscale values
    final gray = List<double>.filled(size * size, 0);
    for (int y = 0; y < size; y++) {
      for (int x = 0; x < size; x++) {
        final pixel = image.getPixel(x, y);
        gray[y * size + x] = 0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b;
      }
    }

    // Apply Laplacian kernel: [0, 1, 0; 1, -4, 1; 0, 1, 0]
    double sum = 0;
    double sumSq = 0;
    int count = 0;

    for (int y = 1; y < size - 1; y++) {
      for (int x = 1; x < size - 1; x++) {
        final laplacian =
            gray[(y - 1) * size + x] +     // top
            gray[(y + 1) * size + x] +     // bottom
            gray[y * size + (x - 1)] +     // left
            gray[y * size + (x + 1)] -     // right
            4.0 * gray[y * size + x];      // center

        sum += laplacian;
        sumSq += laplacian * laplacian;
        count++;
      }
    }

    if (count == 0) return 0;

    final mean = sum / count;
    final variance = (sumSq / count) - (mean * mean);
    return sqrt(variance.abs());
  }
}
