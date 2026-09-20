/// Classification result from either Gemini AI or local TFLite model.
///
/// Wraps the identified plant (if any), confidence score, top predictions,
/// and metadata about the identification source.
class ClassificationResult {
  /// The identified plant, or null if not recognized.
  final dynamic plant; // Plant? — using dynamic to avoid circular import issues

  /// The primary confidence score (0.0 to 1.0).
  final double confidence;

  /// Whether the model explicitly classified this as "Unknown / Not a target plant".
  final bool isUnknown;

  /// Whether the confidence was below the threshold.
  final bool isBelowThreshold;

  /// The identification source: 'gemini', 'tflite', or 'none'.
  final String source;

  /// Whether this was a fallback identification (e.g., Gemini failed, used TFLite).
  final bool isFallback;

  /// Top-N predictions with labels and confidence scores.
  final List<PredictionEntry> topPredictions;

  /// Raw response text or reasoning from the AI.
  final String rawResponse;

  /// Error message, if identification failed entirely.
  final String? errorMessage;

  /// AI disclaimer message to show alongside any result.
  static const String aiDisclaimer =
      'AI identification — verify before treatment or feeding decisions.';

  ClassificationResult({
    this.plant,
    this.confidence = 0.0,
    this.isUnknown = false,
    this.isBelowThreshold = false,
    this.source = 'none',
    this.isFallback = false,
    this.topPredictions = const [],
    this.rawResponse = '',
    this.errorMessage,
  });

  /// True if a plant was successfully identified with sufficient confidence.
  bool get isSuccess => plant != null && !isUnknown && !isBelowThreshold;

  /// True if identification resulted in an error.
  bool get isError => errorMessage != null && plant == null;

  /// True if the plant was not recognized (either Unknown class or low confidence).
  bool get isNotRecognized => isUnknown || isBelowThreshold || (plant == null && errorMessage == null);

  /// Human-readable confidence percentage string.
  String get confidencePercent => '${(confidence * 100).toStringAsFixed(0)}%';

  /// Create a successful result.
  factory ClassificationResult.success({
    required dynamic plant,
    required double confidence,
    required String source,
    bool isFallback = false,
    List<PredictionEntry> topPredictions = const [],
    String rawResponse = '',
  }) {
    return ClassificationResult(
      plant: plant,
      confidence: confidence,
      source: source,
      isFallback: isFallback,
      topPredictions: topPredictions,
      rawResponse: rawResponse,
    );
  }

  /// Create an "Unknown / Not Recognized" result.
  factory ClassificationResult.unknown({
    required String source,
    double confidence = 0.0,
    List<PredictionEntry> topPredictions = const [],
    String rawResponse = '',
  }) {
    return ClassificationResult(
      isUnknown: true,
      confidence: confidence,
      source: source,
      topPredictions: topPredictions,
      rawResponse: rawResponse,
    );
  }

  /// Create a "Below Threshold" result — model had a guess but wasn't confident enough.
  factory ClassificationResult.belowThreshold({
    required String source,
    required double confidence,
    List<PredictionEntry> topPredictions = const [],
    String rawResponse = '',
  }) {
    return ClassificationResult(
      isBelowThreshold: true,
      confidence: confidence,
      source: source,
      topPredictions: topPredictions,
      rawResponse: rawResponse,
    );
  }

  /// Create an error result.
  factory ClassificationResult.error({
    required String errorMessage,
    String rawResponse = '',
  }) {
    return ClassificationResult(
      errorMessage: errorMessage,
      rawResponse: rawResponse,
    );
  }
}

/// A single prediction entry with label and confidence.
class PredictionEntry {
  final String label;
  final double confidence;

  const PredictionEntry({
    required this.label,
    required this.confidence,
  });

  String get confidencePercent => '${(confidence * 100).toStringAsFixed(0)}%';

  @override
  String toString() => '$label ($confidencePercent)';
}
