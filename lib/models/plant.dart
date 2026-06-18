enum SusceptibilityLevel { low, medium, high, critical }

class Plant {
  final String plantId;
  final String tamilName;
  final String englishName;
  final String scientificName;
  final String description;
  final String tamilDescription;
  final String imageUrl;
  final SusceptibilityLevel susceptibilityLevel;
  final bool isEatable;
  final bool isHarmful;
  final String region;
  final String symptoms;
  final String tamilSymptoms;
  final String firstAid;
  final String tamilFirstAid;

  final String hostsAffected;
  final String tamilHostsAffected;
  final String onsetOfSymptoms;
  final String tamilOnsetOfSymptoms;
  final String veterinaryTreatment;
  final String tamilVeterinaryTreatment;
  final String warningMessage;
  final String tamilWarningMessage;
  final String symptomsImageUrl;

  Plant({
    required this.plantId,
    required this.tamilName,
    required this.englishName,
    required this.scientificName,
    required this.description,
    this.tamilDescription = '',
    required this.imageUrl,
    required this.susceptibilityLevel,
    required this.isEatable,
    required this.isHarmful,
    this.region = 'India, South Asia',
    this.symptoms = 'No specific symptoms recorded.',
    this.tamilSymptoms = 'குறிப்பிட்ட அறிகுறிகள் எதுவும் இல்லை.',
    this.firstAid = 'Remove animal from source immediately. Contact vet.',
    this.tamilFirstAid = 'இந்த செடியிலிருந்து விலங்கை அப்புறப்படுத்தவும். மருத்துவரை அணுகவும்.',
    this.hostsAffected = 'Cattle, Goats, Sheep',
    this.tamilHostsAffected = 'மாடுகள், ஆடுகள், செம்மறி ஆடுகள்',
    this.onsetOfSymptoms = 'Within 24 hours of ingestion',
    this.tamilOnsetOfSymptoms = 'உட்கொண்ட 24 மணி நேரத்திற்குள்',
    this.veterinaryTreatment = 'Symptomatic treatment by a veterinarian.',
    this.tamilVeterinaryTreatment = 'கால்நடை மருத்துவரால் அறிகுறி அடிப்படையிலான சிகிச்சை.',
    this.warningMessage = 'Highly Toxic. Keep away from pastures.',
    this.tamilWarningMessage = 'மிகவும் நச்சுத்தன்மை வாய்ந்தது. மேய்ச்சல் நிலங்களிலிருந்து தள்ளி வைக்கவும்.',
    this.symptomsImageUrl = '',
  });

  factory Plant.fromMap(Map<String, dynamic> map) {
    return Plant(
      plantId: map['plantId'] ?? '',
      tamilName: map['tamilName'] ?? '',
      englishName: map['englishName'] ?? '',
      scientificName: map['scientificName'] ?? '',
      description: map['description'] ?? '',
      tamilDescription: map['tamilDescription'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      susceptibilityLevel: SusceptibilityLevel.values.firstWhere(
        (e) => e.name == (map['susceptibilityLevel'] ?? 'low'),
        orElse: () => SusceptibilityLevel.low,
      ),
      isEatable: map['isEatable'] ?? false,
      isHarmful: map['isHarmful'] ?? false,
      region: map['region'] ?? 'India, South Asia',
      symptoms: map['symptoms'] ?? 'No specific symptoms recorded.',
      tamilSymptoms: map['tamilSymptoms'] ?? 'குறிப்பிட்ட அறிகுறிகள் எதுவும் இல்லை.',
      firstAid: map['firstAid'] ?? 'Remove animal from source immediately. Contact vet.',
      tamilFirstAid: map['tamilFirstAid'] ?? 'இந்த செடியிலிருந்து விலங்கை அப்புறப்படுத்தவும். மருத்துவரை அணுகவும்.',
      hostsAffected: map['hostsAffected'] ?? 'Cattle, Goats, Sheep',
      tamilHostsAffected: map['tamilHostsAffected'] ?? 'மாடுகள், ஆடுகள், செம்மறி ஆடுகள்',
      onsetOfSymptoms: map['onsetOfSymptoms'] ?? 'Within 24 hours of ingestion',
      tamilOnsetOfSymptoms: map['tamilOnsetOfSymptoms'] ?? 'உட்கொண்ட 24 மணி நேரத்திற்குள்',
      veterinaryTreatment: map['veterinaryTreatment'] ?? 'Symptomatic treatment by a veterinarian.',
      tamilVeterinaryTreatment: map['tamilVeterinaryTreatment'] ?? 'கால்நடை மருத்துவரால் அறிகுறி அடிப்படையிலான சிகிச்சை.',
      warningMessage: map['warningMessage'] ?? 'Highly Toxic. Keep away from pastures.',
      tamilWarningMessage: map['tamilWarningMessage'] ?? 'மிகவும் நச்சுத்தன்மை வாய்ந்தது. மேய்ச்சல் நிலங்களிலிருந்து தள்ளி வைக்கவும்.',
      symptomsImageUrl: map['symptomsImageUrl'] ?? '',
    );
  }
}
