import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../models/plant.dart';
import '../models/classification_result.dart';
import '../data/mock_plants.dart';

/// Service that uses Google Gemini API to identify plants from photos.
class GeminiPlantService {
  static const String _defaultApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: 'AIzaSyAb8RN6Jeooc5gZaZHvcxdlFO-A1-XzTRykKAKoao1A',
  );

  late final GenerativeModel _model;

  GeminiPlantService({String? apiKey}) {
    final key = (apiKey != null && apiKey.isNotEmpty) ? apiKey : _defaultApiKey;
    _model = GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: key,
      generationConfig: GenerationConfig(
        temperature: 0.2,
        maxOutputTokens: 1024,
        responseMimeType: 'application/json',
        responseSchema: Schema.object(
          properties: {
            'scientific_name': Schema.string(
              description: 'Exact Scientific Name. If unknown, return "unknown"',
            ),
            'english_name': Schema.string(
              description: 'Common English Name. If unknown, return "Unknown Plant"',
            ),
            'confidence': Schema.number(
              description: 'Confidence score between 0.0 and 1.0',
            ),
            'reasoning': Schema.string(
              description: 'Brief explanation of identifying features or why it could not be identified',
            ),
          },
          requiredProperties: ['scientific_name', 'english_name', 'confidence', 'reasoning'],
        ),
      ),
    );
  }

  /// Build the plant identification prompt with all known plants.
  String _buildPrompt() {
    final plantNames = mockPlants.map((p) =>
      '- ${p.scientificName} (${p.englishName})'
    ).join('\n');

    return '''You are an expert botanist specializing in livestock-toxic plant identification.

Analyze the provided plant image and identify which plant it is from the following known database:

$plantNames

INSTRUCTIONS:
1. Carefully examine the plant's leaves, flowers, fruits, stems, and overall morphology.
2. CRITICAL: You must strictly match the plant to EXACTLY ONE of the plants in the list above. Do NOT guess a plant that is not in the list.
3. Pay close attention to distinguishing features (e.g., Bracken Fern has large triangular fronds/leaves, Lantana has small colorful flower clusters). Do not confuse them!
4. Respond ONLY with valid JSON in exactly this format (no markdown, no code fences):

{"scientific_name": "Exact Scientific Name", "english_name": "Common English Name", "confidence": 0.95, "reasoning": "Brief explanation of identifying features"}

RULES:
- "scientific_name" MUST exactly match one from the list above.
- "confidence" must be a number between 0.0 and 1.0.
- If the image does not clearly show a plant, or the plant is not in the list, respond with:
  {"scientific_name": "unknown", "english_name": "Unknown Plant", "confidence": 0.0, "reasoning": "Explanation of why it could not be identified"}
- Do NOT wrap the JSON in markdown code blocks. Return raw JSON only.
''';
  }

  /// Identify a plant from an image file using Gemini Vision AI.
  Future<ClassificationResult> identifyPlant(File imageFile) async {
    try {
      debugPrint('Attempting Gemini AI Vision identification...');
      final imageBytes = await imageFile.readAsBytes();
      final extension = imageFile.path.split('.').last.toLowerCase();
      final mimeType = switch (extension) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'webp' => 'image/webp',
        'gif' => 'image/gif',
        _ => 'image/jpeg',
      };

      final content = [
        Content.multi([
          TextPart(_buildPrompt()),
          DataPart(mimeType, imageBytes),
        ])
      ];

      final response = await _model.generateContent(content);
      final responseText = response.text ?? '';

      debugPrint('Gemini raw response: $responseText');

      final result = _parseResponse(responseText);
      return result;

    } catch (e) {
      debugPrint('Gemini API error ($e).');
      return ClassificationResult.error(
        errorMessage: 'Could not connect to AI service. Please try again.',
        rawResponse: 'Error: $e',
      );
    }
  }

  /// Parse Gemini's JSON response and match to a Plant in our database.
  ClassificationResult _parseResponse(String responseText) {
    try {
      // Clean up response — strip markdown code fences if present
      String cleaned = responseText.trim();
      if (cleaned.startsWith('```')) {
        cleaned = cleaned.replaceAll(RegExp(r'^```(?:json)?\s*'), '');
        cleaned = cleaned.replaceAll(RegExp(r'\s*```$'), '');
      }

      final json = jsonDecode(cleaned) as Map<String, dynamic>;

      final scientificName = json['scientific_name'] as String? ?? 'unknown';
      final confidence = (json['confidence'] as num?)?.toDouble() ?? 0.0;
      final reasoning = json['reasoning'] as String? ?? '';

      // Check if unknown
      if (scientificName.toLowerCase() == 'unknown') {
        return ClassificationResult.unknown(
          source: 'gemini',
          confidence: confidence,
          rawResponse: reasoning,
        );
      }

      // Find matching plant in our database (case-insensitive)
      Plant? matchedPlant;
      for (final plant in mockPlants) {
        if (plant.scientificName.toLowerCase() == scientificName.toLowerCase()) {
          matchedPlant = plant;
          break;
        }
      }

      // Fallback: try partial match on english name
      if (matchedPlant == null) {
        final englishName = (json['english_name'] as String? ?? '').toLowerCase();
        for (final plant in mockPlants) {
          if (plant.englishName.toLowerCase().contains(englishName) ||
              englishName.contains(plant.englishName.toLowerCase())) {
            matchedPlant = plant;
            break;
          }
        }
      }

      // Fallback: try partial match on scientific name
      if (matchedPlant == null) {
        for (final plant in mockPlants) {
          if (plant.scientificName.toLowerCase().contains(scientificName.toLowerCase().split(' ').first)) {
            matchedPlant = plant;
            break;
          }
        }
      }

      if (matchedPlant != null) {
        return ClassificationResult.success(
          plant: matchedPlant,
          confidence: confidence,
          source: 'gemini',
          rawResponse: reasoning,
        );
      }

      // No match found in database
      return ClassificationResult.unknown(
        source: 'gemini',
        confidence: confidence,
        rawResponse: 'Predicted $scientificName but not found in plant database. $reasoning',
      );

    } catch (e) {
      debugPrint('Failed to parse Gemini response: $e');
      debugPrint('Raw response was: $responseText');
      return ClassificationResult.error(
        errorMessage: 'Could not parse AI response. Please try again.',
        rawResponse: responseText,
      );
    }
  }
}
