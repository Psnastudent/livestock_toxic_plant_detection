import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../data/vet_hospitals.dart';

/// Holds the app-wide live location state.
class LocationState {
  final Position? position;
  final bool isLocationEnabled;
  final VetHospital? nearestHospital;
  final double distanceKm;
  final List<VetHospital> nearbyHospitals;
  final bool isLoading;

  const LocationState({
    this.position,
    this.isLocationEnabled = true,
    this.nearestHospital,
    this.distanceKm = 0.0,
    this.nearbyHospitals = const [],
    this.isLoading = true,
  });

  LocationState copyWith({
    Position? position,
    bool? isLocationEnabled,
    VetHospital? nearestHospital,
    double? distanceKm,
    List<VetHospital>? nearbyHospitals,
    bool? isLoading,
  }) {
    return LocationState(
      position: position ?? this.position,
      isLocationEnabled: isLocationEnabled ?? this.isLocationEnabled,
      nearestHospital: nearestHospital ?? this.nearestHospital,
      distanceKm: distanceKm ?? this.distanceKm,
      nearbyHospitals: nearbyHospitals ?? this.nearbyHospitals,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class LocationNotifier extends StateNotifier<LocationState> {
  StreamSubscription<Position>? _positionStream;

  LocationNotifier() : super(const LocationState());

  /// Initialize location — call this on every app launch.
  Future<void> initLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        state = state.copyWith(isLocationEnabled: false, isLoading: false);
        return;
      }

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) {
          state = state.copyWith(isLocationEnabled: false, isLoading: false);
          return;
        }
      }
      if (perm == LocationPermission.deniedForever) {
        state = state.copyWith(isLocationEnabled: false, isLoading: false);
        return;
      }

      // Get the current position
      final pos = await Geolocator.getCurrentPosition();
      _updateStateWithPosition(pos);

      // Start live stream for continuous updates
      _positionStream?.cancel();
      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen(
        (pos) => _updateStateWithPosition(pos),
        onError: (e) {
          debugPrint('Location stream error: $e');
        },
      );
    } catch (e) {
      debugPrint('Error fetching location: $e');
      state = state.copyWith(isLocationEnabled: false, isLoading: false);
    }
  }

  /// Update state with a new position and recalculate nearby hospitals.
  void _updateStateWithPosition(Position pos) {
    final nearest = findNearestHospital(pos.latitude, pos.longitude);
    final dist = getDistanceInKm(
      pos.latitude,
      pos.longitude,
      nearest.latitude,
      nearest.longitude,
    );

    // Sort all hospitals by distance from current position
    final sorted = List<VetHospital>.from(vetHospitals)
      ..sort((a, b) {
        final dA = Geolocator.distanceBetween(
          pos.latitude, pos.longitude, a.latitude, a.longitude,
        );
        final dB = Geolocator.distanceBetween(
          pos.latitude, pos.longitude, b.latitude, b.longitude,
        );
        return dA.compareTo(dB);
      });

    state = LocationState(
      position: pos,
      isLocationEnabled: true,
      nearestHospital: nearest,
      distanceKm: dist,
      nearbyHospitals: sorted,
      isLoading: false,
    );
  }

  /// Manually refresh location (e.g. after user turns on GPS).
  Future<void> refreshLocation() async {
    state = state.copyWith(isLoading: true);
    await initLocation();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }
}

final locationProvider =
    StateNotifierProvider<LocationNotifier, LocationState>((ref) {
  return LocationNotifier();
});
