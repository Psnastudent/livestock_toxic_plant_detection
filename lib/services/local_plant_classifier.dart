import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../models/plant.dart';
import '../models/classification_result.dart';
import '../data/mock_plants.dart';

/// Service that classifies plant photos locally offline using a trained TFLite model.
///
/// V2 improvements:
/// - Loads confidence threshold from threshold.json (computed during training)
/// - Handles "Unknown" class explicitly
/// - Returns ClassificationResult with top-N predictions
/// - Returns confidence information for UI display
class LocalPlantClassifier {
  static Interpreter? _interpreter;
  static List<String> _labels = [];
  static bool _isModelLoaded = false;
  static double _confidenceThreshold = 0.70; // Default, overridden by threshold.json
  static int _unknownClassIndex = -1; // Index of "Unknown" label, if present

  /// Loads the TFLite model, labels, and threshold into memory.
  static Future<void> loadModel() async {
    if (_isModelLoaded) return;
    try {
      _interpreter = await Interpreter.fromAsset('assets/model/plant_classifier.tflite');
      final labelData = await rootBundle.loadString('assets/model/labels.txt');
      _labels = labelData.split('\n').where((s) => s.trim().isNotEmpty).toList();
      _isModelLoaded = true;

      // Find the "Unknown" class index if it exists in labels
      for (int i = 0; i < _labels.length; i++) {
        if (_labels[i].trim().toLowerCase() == 'unknown') {
          _unknownClassIndex = i;
          break;
        }
      }

      // Load optimal threshold from threshold.json (generated during training)
      try {
        final thresholdData = await rootBundle.loadString('assets/model/threshold.json');
        final thresholdJson = jsonDecode(thresholdData) as Map<String, dynamic>;
        _confidenceThreshold = (thresholdJson['optimal_threshold'] as num?)?.toDouble() ?? 0.70;
        debugPrint("Loaded confidence threshold: $_confidenceThreshold");
      } catch (e) {
        debugPrint("threshold.json not found, using default threshold: $_confidenceThreshold");
      }

      debugPrint("Local TFLite model loaded successfully. "
          "Classes: ${_labels.length}, "
          "Unknown index: $_unknownClassIndex, "
          "Threshold: $_confidenceThreshold");
    } catch (e) {
      debugPrint("Error loading TFLite model: $e");
    }
  }

  /// Classify a plant image locally.
  ///
  /// Returns a [ClassificationResult] with:
  /// - Success: identified plant with confidence
  /// - Unknown: model's top prediction is the "Unknown" class
  /// - BelowThreshold: confidence too low to be reliable
  /// - Error: something went wrong
  static Future<ClassificationResult> classify(File imageFile) async {
    if (!_isModelLoaded) {
      await loadModel();
    }
    if (_interpreter == null || _labels.isEmpty) {
      return ClassificationResult.error(
        errorMessage: 'Plant classifier model could not be loaded.',
      );
    }

    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) {
        return ClassificationResult.error(
          errorMessage: 'Could not decode image.',
        );
      }

      // Resize to match MobileNetV2 input size
      final resized = img.copyResize(image, width: 224, height: 224);

      // Prepare input tensor [1, 224, 224, 3] of float32
      var input = List.generate(
        1,
        (i) => List.generate(
          224,
          (y) => List.generate(
            224,
            (x) => List.filled(3, 0.0),
          ),
        ),
      );

      for (int y = 0; y < 224; y++) {
        for (int x = 0; x < 224; x++) {
          final pixel = resized.getPixel(x, y);
          input[0][y][x][0] = pixel.r.toDouble();
          input[0][y][x][1] = pixel.g.toDouble();
          input[0][y][x][2] = pixel.b.toDouble();
        }
      }

      // Prepare output tensor [1, num_classes]
      var output = List.generate(1, (i) => List.filled(_labels.length, 0.0));

      // Run inference
      _interpreter!.run(input, output);

      // Get all probabilities and sort to find top-N predictions
      final probs = output[0];
      final indexed = List.generate(probs.length, (i) => MapEntry(i, probs[i]));
      indexed.sort((a, b) => b.value.compareTo(a.value));

      // Top 3 predictions for display
      final topPredictions = indexed.take(3).map((entry) {
        return PredictionEntry(
          label: _labels[entry.key].trim(),
          confidence: entry.value,
        );
      }).toList();

      final bestIndex = indexed[0].key;
      final bestConfidence = indexed[0].value;
      final bestLabel = _labels[bestIndex].trim();

      debugPrint("TFLite predicted: $bestLabel with confidence $bestConfidence");
      debugPrint("Top 3: ${topPredictions.join(', ')}");

      // Check 1: Is the top prediction the "Unknown" class?
      if (bestIndex == _unknownClassIndex) {
        debugPrint("TFLite predicted Unknown class.");
        return ClassificationResult.unknown(
          source: 'tflite',
          confidence: bestConfidence,
          topPredictions: topPredictions,
          rawResponse: 'Model classified this as an unknown/non-target plant.',
        );
      }

      // Check 2: Is confidence below threshold?
      if (bestConfidence < _confidenceThreshold) {
        debugPrint("TFLite confidence ($bestConfidence) below threshold ($_confidenceThreshold).");
        return ClassificationResult.belowThreshold(
          source: 'tflite',
          confidence: bestConfidence,
          topPredictions: topPredictions,
          rawResponse: 'Confidence too low for reliable identification.',
        );
      }

      // Check 3: Check if top two predictions are too close (ambiguous)
      if (indexed.length >= 2) {
        final secondConfidence = indexed[1].value;
        final gap = bestConfidence - secondConfidence;
        if (gap < 0.15 && bestConfidence < 0.85) {
          debugPrint("TFLite predictions too close: $bestConfidence vs $secondConfidence (gap=$gap)");
          return ClassificationResult.belowThreshold(
            source: 'tflite',
            confidence: bestConfidence,
            topPredictions: topPredictions,
            rawResponse: 'Multiple plants match with similar confidence.',
          );
        }
      }

      // Match the predicted label to a plant in our database
      final labelLower = bestLabel.toLowerCase();
      Plant? matchedPlant;

      for (final plant in mockPlants) {
        final sci = plant.scientificName.toLowerCase();
        if (labelLower == sci || labelLower.contains(sci) || sci.contains(labelLower)) {
          matchedPlant = plant;
          break;
        }
      }

      if (matchedPlant != null) {
        return ClassificationResult.success(
          plant: matchedPlant,
          confidence: bestConfidence,
          source: 'tflite',
          topPredictions: topPredictions,
          rawResponse: 'Identified using trained local plant classifier model.',
        );
      }

      // Label predicted but not found in database
      debugPrint("TFLite predicted $bestLabel but could not map to any plant in database.");
      return ClassificationResult.unknown(
        source: 'tflite',
        confidence: bestConfidence,
        topPredictions: topPredictions,
        rawResponse: 'Predicted $bestLabel but not found in plant database.',
      );

    } catch (e) {
      debugPrint('LocalPlantClassifier exception: $e');
      return ClassificationResult.error(
        errorMessage: 'Classification failed: $e',
      );
    }
  }

  /// Get the current confidence threshold (for display purposes).
  static double get confidenceThreshold => _confidenceThreshold;

  /// Whether the model includes an "Unknown" class.
  static bool get hasUnknownClass => _unknownClassIndex != -1;
}
