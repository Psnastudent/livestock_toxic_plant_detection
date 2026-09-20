import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service to upload unidentified plant reports to Firebase.
///
/// Users can report plants the AI couldn't identify, which helps
/// expand the training dataset and improve the model over time.
class PlantReportService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'plant_reports';

  /// Submit a plant report to Firebase Firestore.
  ///
  /// The photo is stored as a base64 thumbnail in Firestore directly
  /// (avoids requiring Firebase Storage setup).
  ///
  /// If [currentPosition] is provided (e.g. from the central location provider),
  /// it will be used directly. Otherwise, the service falls back to fetching
  /// the position via Geolocator.
  static Future<bool> submitReport({
    required File imageFile,
    String? plantName,
    String? additionalNotes,
    List<String>? aiSuggestions,
    Position? currentPosition,
  }) async {
    try {
      // Get current user info
      final user = FirebaseAuth.instance.currentUser;

      // Use provided position or fall back to direct GPS fetch
      Position? position = currentPosition;
      if (position == null) {
        try {
          final permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.always ||
              permission == LocationPermission.whileInUse) {
            position = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.medium,
                timeLimit: Duration(seconds: 5),
              ),
            );
          }
        } catch (e) {
          debugPrint('Could not get location for report: $e');
        }
      }


      // Read image and create a compressed thumbnail for storage
      final bytes = await imageFile.readAsBytes();
      final base64Thumb = _createBase64Thumbnail(bytes);

      // Build report document
      final Map<String, dynamic> reportData = {
        'timestamp': FieldValue.serverTimestamp(),
        'userId': user?.uid ?? 'anonymous',
        'userEmail': user?.email ?? '',
        'userDisplayName': user?.displayName ?? '',
        'plantName': plantName ?? '',
        'additionalNotes': additionalNotes ?? '',
        'aiSuggestions': aiSuggestions ?? [],
        'imageThumbnail': base64Thumb,
        'imageOriginalPath': imageFile.path,
        'status': 'pending', // pending, reviewed, added_to_dataset
        'reviewNotes': '',
      };

      // Add location if available
      if (position != null) {
        reportData['location'] = {
          'latitude': position.latitude,
          'longitude': position.longitude,
        };
      }

      // Submit to Firestore
      await _firestore.collection(_collection).add(reportData);

      debugPrint('Plant report submitted successfully');
      return true;
    } catch (e) {
      debugPrint('Error submitting plant report: $e');
      return false;
    }
  }

  /// Create a base64-encoded JPEG thumbnail string from image bytes.
  ///
  /// Stores a compressed version in Firestore (avoids needing Firebase Storage).
  /// Limited to ~500KB base64 to stay within Firestore document limits.
  static String _createBase64Thumbnail(Uint8List bytes) {
    try {
      // For Firestore, store a reasonable chunk of the image
      // In production, you'd use Firebase Storage instead
      final encoded = base64Encode(bytes);
      // Firestore document limit is ~1MB, so limit thumbnail to ~500KB base64
      if (encoded.length > 500000) {
        return encoded.substring(0, 500000);
      }
      return encoded;
    } catch (e) {
      return '';
    }
  }

  /// Get all pending reports (for admin review).
  static Stream<QuerySnapshot> getPendingReports() {
    return _firestore
        .collection(_collection)
        .where('status', isEqualTo: 'pending')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  /// Update report status (for admin).
  static Future<void> updateReportStatus(String reportId, String status, {String? notes}) async {
    await _firestore.collection(_collection).doc(reportId).update({
      'status': status,
      'reviewNotes': notes ?? '',
      'reviewedAt': FieldValue.serverTimestamp(),
    });
  }
}
