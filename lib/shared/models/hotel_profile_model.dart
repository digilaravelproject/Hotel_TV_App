import 'dart:convert';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/storage/shared_prefs.dart';

class EmergencyContacts {
  final String reception;
  final String dining;
  final String medicalSos;
  final String email;

  const EmergencyContacts({
    this.reception = '',
    this.dining = '',
    this.medicalSos = '',
    this.email = '',
  });

  factory EmergencyContacts.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const EmergencyContacts();
    return EmergencyContacts(
      reception: map['reception']?.toString() ?? '',
      dining: map['dining']?.toString() ?? '',
      medicalSos: map['medical_sos']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
    );
  }
}

class HotelMedia {
  final String logoImage;
  final String coverImage;
  final List<String> sliderImages;

  const HotelMedia({
    this.logoImage = '',
    this.coverImage = '',
    this.sliderImages = const [],
  });

  factory HotelMedia.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const HotelMedia();
    final rawSliders = map['slider_images'];
    List<String> sliders = [];
    if (rawSliders is List) {
      sliders = rawSliders.map((e) => e.toString()).toList();
    }
    return HotelMedia(
      logoImage: map['logo_image']?.toString() ?? '',
      coverImage: map['cover_image']?.toString() ?? '',
      sliderImages: sliders,
    );
  }
}

class HotelProfileModel {
  final String name;
  final String city;
  final String location;
  final String timezone;
  final String description;
  final String ownerName;
  final String email;
  final String phone;
  final EmergencyContacts emergencyContacts;
  final HotelMedia media;

  const HotelProfileModel({
    this.name = 'PAX HOSPITALITY',
    this.city = '',
    this.location = '',
    this.timezone = 'Asia/Kolkata',
    this.description = '',
    this.ownerName = '',
    this.email = '',
    this.phone = '',
    this.emergencyContacts = const EmergencyContacts(),
    this.media = const HotelMedia(),
  });

  factory HotelProfileModel.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const HotelProfileModel();
    final rawName = map['hotel_name'] ?? map['name'] ?? 'PAX HOSPITALITY';
    return HotelProfileModel(
      name: rawName.toString().trim().isNotEmpty ? rawName.toString().trim() : 'PAX HOSPITALITY',
      city: map['city']?.toString() ?? '',
      location: map['hotel_location']?.toString() ?? map['location']?.toString() ?? '',
      timezone: map['timezone']?.toString() ?? 'Asia/Kolkata',
      description: map['description']?.toString() ?? '',
      ownerName: map['owner_name']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      emergencyContacts: EmergencyContacts.fromMap(map['emergency_contacts'] as Map<String, dynamic>?),
      media: HotelMedia.fromMap(map['media'] as Map<String, dynamic>?),
    );
  }

  /// Safe single-source-of-truth reader directly from local storage
  static HotelProfileModel? _cachedInstance;

  static HotelProfileModel current() {
    if (_cachedInstance != null) return _cachedInstance!;
    try {
      final rawData = SharedPrefs.getString(AppConstants.tvLoginDataKey);
      if (rawData != null && rawData.isNotEmpty) {
        final decoded = jsonDecode(rawData);
        final dataMap = decoded['data'] ?? decoded;
        final hotelMap = dataMap['hotel'] as Map<String, dynamic>?;
        if (hotelMap != null) {
          _cachedInstance = HotelProfileModel.fromMap(hotelMap);
          return _cachedInstance!;
        }
      }
    } catch (_) {}
    return const HotelProfileModel();
  }

  static void invalidateCache() {
    _cachedInstance = null;
  }
}
