import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppLanguage { english, tamil }

final languageProvider = StateProvider<AppLanguage>((ref) => AppLanguage.english);

final translationProvider = Provider<Map<String, Map<String, String>>>((ref) {
  return {
    // ── Home Screen ──
    'greeting': {
      'english': 'Hi, Farmer 👋',
      'tamil': 'வணக்கம், விவசாயி 👋',
    },
    'subtitle_label': {
      'english': 'LIVESTOCK SAFETY',
      'tamil': 'கால்நடை பாதுகாப்பு',
    },
    'main_title': {
      'english': 'Plant\nDetection',
      'tamil': 'தாவர\nஅடையாளம்',
    },
    'search_hint': {
      'english': 'Search plants...',
      'tamil': 'தாவரங்களைத் தேடுக...',
    },
    'scan_plant': {
      'english': 'Scan Plant',
      'tamil': 'தாவரத்தை ஸ்கேன் செய்',
    },
    'scan_subtitle': {
      'english': 'Identify plants with AI camera',
      'tamil': 'AI கேமராவுடன் தாவரங்களை அடையாளம் காணுங்கள்',
    },
    'common_toxic_plants': {
      'english': 'Toxic Plants',
      'tamil': 'நச்சுத் தாவரங்கள்',
    },
    'safe_plants': {
      'english': 'Safe for Livestock',
      'tamil': 'கால்நடைகளுக்கு பாதுகாப்பானது',
    },
    'view_all': {
      'english': 'View All',
      'tamil': 'அனைத்தும் காண',
    },
    
    // ── Categories ──
    'all': {
      'english': 'All',
      'tamil': 'அனைத்தும்',
    },
    'toxic': {
      'english': 'Toxic',
      'tamil': 'நச்சு',
    },
    'safe': {
      'english': 'Safe',
      'tamil': 'பாதுகாப்பு',
    },
    'critical': {
      'english': 'Critical',
      'tamil': 'மிக அதிக',
    },
    'edible': {
      'english': 'Edible',
      'tamil': 'உண்ணத்தக்கது',
    },
    'not_fodder': {
      'english': 'Not Fodder',
      'tamil': 'தீவனம் அல்ல',
    },

    // ── Details Screen ──
    'about_plant': {
      'english': 'About this Plant',
      'tamil': 'இந்த தாவரம் பற்றி',
    },
    'toxicity_warning': {
      'english': 'Warning: Keep livestock away immediately. Can cause severe health issues or death.',
      'tamil': 'எச்சரிக்கை: கால்நடைகளை உடனடியாக விலக்கி வையுங்கள். கடுமையான உடல்நல பிரச்சினைகள் அல்லது மரணத்தை ஏற்படுத்தும்.',
    },
    'toxicity_level': {
      'english': 'Toxicity',
      'tamil': 'நச்சுத்தன்மை',
    },
    'susceptibility': {
      'english': 'Risk Level',
      'tamil': 'ஆபத்து நிலை',
    },
    'edibility': {
      'english': 'Edibility',
      'tamil': 'உண்ணும் தன்மை',
    },
    'nearest_vet': {
      'english': 'Nearest Veterinary',
      'tamil': 'அருகிலுள்ள கால்நடை மருத்துவமனை',
    },
    'live_location': {
      'english': 'Live location active',
      'tamil': 'நேரடி இருப்பிடம் செயலில்',
    },
    'acquiring_location': {
      'english': 'Acquiring location...',
      'tamil': 'இருப்பிடம் பெறுகிறது...',
    },

    // ── Scan Screen ──
    'identify_plant': {
      'english': 'Identify Plant',
      'tamil': 'தாவரத்தை அடையாளம் காணுக',
    },
    'position_plant': {
      'english': 'Position plant in center',
      'tamil': 'தாவரத்தை மையத்தில் வையுங்கள்',
    },
    'take_photo': {
      'english': 'Take Photo',
      'tamil': 'புகைப்படம் எடு',
    },
    'gallery': {
      'english': 'Gallery',
      'tamil': 'கேலரி',
    },
    'scanning': {
      'english': 'Running AI plant detection...',
      'tamil': 'AI தாவர கண்டறிதல் இயங்குகிறது...',
    },

    // ── Search Screen ──
    'plant_dictionary': {
      'english': 'Plant Dictionary',
      'tamil': 'தாவர அகராதி',
    },
    'search_by_name': {
      'english': 'Search by name or scientific name...',
      'tamil': 'பெயர் அல்லது அறிவியல் பெயரால் தேடுக...',
    },
    'plants_found': {
      'english': 'plants found',
      'tamil': 'தாவரங்கள் கண்டறியப்பட்டன',
    },
    'no_plants_found': {
      'english': 'No plants found.',
      'tamil': 'தாவரங்கள் எதுவும் கிடைக்கவில்லை.',
    },
    'harmful': {
      'english': 'Harmful',
      'tamil': 'தீங்கு',
    },
    'harmless': {
      'english': 'Harmless',
      'tamil': 'பாதுகாப்பு',
    },
    'eatable': {
      'english': 'Eatable',
      'tamil': 'உண்ணத்தக்கது',
    },
    'not_eatable': {
      'english': 'Not Eatable',
      'tamil': 'உண்ண இயலாதது',
    },

    // ── Profile Screen ──
    'profile': {
      'english': 'Profile',
      'tamil': 'சுயவிவரம்',
    },
    'dark_mode': {
      'english': 'Dark Mode',
      'tamil': 'இருண்ட பயன்முறை',
    },
    'logout': {
      'english': 'Logout',
      'tamil': 'வெளியேறு',
    },
    'language': {
      'english': 'Language',
      'tamil': 'மொழி',
    },
    'app_version': {
      'english': 'App Version 1.0.0',
      'tamil': 'பயன்பாட்டு பதிப்பு 1.0.0',
    },

    // ── Login Screen ──
    'app_name': {
      'english': 'AgriGuard',
      'tamil': 'அக்ரிகார்ட்',
    },
    'app_tagline': {
      'english': 'Protect livestock · Identify toxic plants',
      'tamil': 'கால்நடைகளைப் பாதுகாக்கவும் · நச்சு தாவரங்களை அடையாளம் காணவும்',
    },
    'get_started': {
      'english': 'Get Started',
      'tamil': 'தொடங்குங்கள்',
    },
    'plants_count': {
      'english': '22+',
      'tamil': '22+',
    },
    'plants_label': {
      'english': 'Plants',
      'tamil': 'தாவரங்கள்',
    },
    'ai_label': {
      'english': 'AI',
      'tamil': 'AI',
    },
    'detection_label': {
      'english': 'Detection',
      'tamil': 'கண்டறிதல்',
    },
    'live_label': {
      'english': 'Live',
      'tamil': 'நேரடி',
    },
    'location_label': {
      'english': 'Location',
      'tamil': 'இருப்பிடம்',
    },

    // ── Bottom Nav ──
    'home': {
      'english': 'Home',
      'tamil': 'முகப்பு',
    },
    'search': {
      'english': 'Search',
      'tamil': 'தேடு',
    },
    'scan': {
      'english': 'Scan',
      'tamil': 'ஸ்கேன்',
    },
    'dictionary': {
      'english': 'Plants',
      'tamil': 'தாவரங்கள்',
    },

    // ── Susceptibility Levels ──
    'low': {
      'english': 'Low',
      'tamil': 'குறைந்த',
    },
    'medium': {
      'english': 'Medium',
      'tamil': 'நடுத்தர',
    },
    'high': {
      'english': 'High',
      'tamil': 'அதிக',
    },
  };
});
