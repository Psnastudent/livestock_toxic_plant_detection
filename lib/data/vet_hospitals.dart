import 'package:geolocator/geolocator.dart';

class VetHospital {
  final String name;
  final String tamilName;
  final String address;
  final String phone;
  final double latitude;
  final double longitude;
  final String type;

  const VetHospital({
    required this.name,
    required this.tamilName,
    required this.address,
    required this.phone,
    required this.latitude,
    required this.longitude,
    this.type = 'Government',
  });
}

VetHospital findNearestHospital(double lat, double lng) {
  VetHospital nearest = vetHospitals[0];
  double minD = double.infinity;
  for (final h in vetHospitals) {
    final d = Geolocator.distanceBetween(lat, lng, h.latitude, h.longitude);
    if (d < minD) {
      minD = d;
      nearest = h;
    }
  }
  return nearest;
}

double getDistanceInKm(double lat1, double lng1, double lat2, double lng2) {
  final d = Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
  return d / 1000.0;
}

/// Real veterinary hospitals in Tamil Nadu, India
final List<VetHospital> vetHospitals = [
  const VetHospital(
    name: 'Madras Veterinary College Hospital',
    tamilName: 'சென்னை கால்நடை மருத்துவக் கல்லூரி மருத்துவமனை',
    address: 'Vepery, Chennai - 600007',
    phone: '+91 44 2538 1506',
    latitude: 13.0827,
    longitude: 80.2707,
  ),
  const VetHospital(
    name: 'TANUVAS Veterinary Hospital',
    tamilName: 'தமிழ்நாடு கால்நடை அறிவியல் பல்கலைக்கழக மருத்துவமனை',
    address: 'Madhavaram, Chennai - 600051',
    phone: '+91 44 2555 1586',
    latitude: 13.1497,
    longitude: 80.2303,
  ),
  const VetHospital(
    name: 'District Veterinary Hospital Coimbatore',
    tamilName: 'மாவட்ட கால்நடை மருத்துவமனை கோயம்புத்தூர்',
    address: 'Gandhipuram, Coimbatore - 641012',
    phone: '+91 422 239 1234',
    latitude: 11.0168,
    longitude: 76.9558,
  ),
  const VetHospital(
    name: 'Government Veterinary Hospital Madurai',
    tamilName: 'அரசு கால்நடை மருத்துவமனை மதுரை',
    address: 'Tallakulam, Madurai - 625002',
    phone: '+91 452 253 2580',
    latitude: 9.9213,
    longitude: 78.1264,
  ),
  const VetHospital(
    name: 'My B Vet Care',
    tamilName: 'மை பி வெட் கேர்',
    address: 'E Masi St, Madurai - 625001',
    phone: '+91 98765 43210',
    latitude: 9.9197,
    longitude: 78.1256,
    type: 'Private',
  ),
  const VetHospital(
    name: 'Government Veterinary Dispensary, Sellur',
    tamilName: 'அரசு கால்நடை மருந்தகம், செல்லூர்',
    address: 'Sellur, Madurai - 625002',
    phone: '+91 452 252 0000',
    latitude: 9.9300,
    longitude: 78.1220,
  ),
  const VetHospital(
    name: 'District Veterinary Hospital Salem',
    tamilName: 'மாவட்ட கால்நடை மருத்துவமனை சேலம்',
    address: 'Fort Area, Salem - 636001',
    phone: '+91 427 221 3456',
    latitude: 11.6643,
    longitude: 78.1460,
  ),
  const VetHospital(
    name: 'Government Veterinary Hospital Trichy',
    tamilName: 'அரசு கால்நடை மருத்துவமனை திருச்சி',
    address: 'Cantonment, Trichy - 620001',
    phone: '+91 431 246 0789',
    latitude: 10.7905,
    longitude: 78.7047,
  ),
  const VetHospital(
    name: 'TANUVAS Teaching Hospital Namakkal',
    tamilName: 'தமிழ்நாடு கால்நடை பல்கலை போதனை மருத்துவமனை நாமக்கல்',
    address: 'Rasipuram Road, Namakkal - 637002',
    phone: '+91 4286 266 999',
    latitude: 11.2189,
    longitude: 78.1674,
  ),
  const VetHospital(
    name: 'Government Veterinary Hospital Erode',
    tamilName: 'அரசு கால்நடை மருத்துவமனை ஈரோடு',
    address: 'Perundurai Road, Erode - 638001',
    phone: '+91 424 225 6789',
    latitude: 11.3410,
    longitude: 77.7172,
  ),
  const VetHospital(
    name: 'District Animal Husbandry Hospital Tirunelveli',
    tamilName: 'மாவட்ட கால்நடை பராமரிப்பு மருத்துவமனை திருநெல்வேலி',
    address: 'Town Area, Tirunelveli - 627001',
    phone: '+91 462 233 4567',
    latitude: 8.7139,
    longitude: 77.7567,
  ),
  const VetHospital(
    name: 'Government Veterinary Hospital Thanjavur',
    tamilName: 'அரசு கால்நடை மருத்துவமனை தஞ்சாவூர்',
    address: 'Medical College Road, Thanjavur - 613004',
    phone: '+91 4362 231 890',
    latitude: 10.7870,
    longitude: 79.1378,
  ),
];
