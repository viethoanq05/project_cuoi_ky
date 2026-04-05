import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'dart:convert';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Cache địa chỉ để tránh gọi API nhiều lần
  static final Map<String, String> _addressCache = {};

  bool _looksLikeVietnamCoords(double lat, double lng) {
    // Rough bounding box for Vietnam to detect obvious mis-resolutions.
    return lat >= 8.0 && lat <= 24.5 && lng >= 102.0 && lng <= 110.0;
  }

  Future<String?> _reverseWithNominatimVietnam(double lat, double lng) async {
    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1&countrycodes=vn',
    );
    final response = await http.get(
      url,
      headers: {
        'Accept-Language': 'vi',
        // Some Nominatim instances require a UA.
        'User-Agent': 'project_cuoi_ky/1.0',
      },
    );
    if (response.statusCode != 200) return null;
    final data = json.decode(response.body);
    final display = (data is Map) ? (data['display_name']?.toString()) : null;
    final trimmed = display?.trim() ?? '';
    return trimmed.isNotEmpty ? trimmed : null;
  }

  Future<Map<String, dynamic>?> getUserById(String uid) async {
    if (uid.isEmpty) return null;
    try {
      final doc = await _firestore.collection('Users').doc(uid).get();
      if (doc.exists) return doc.data();

      final query = await _firestore
          .collection('Users')
          .where('email', isEqualTo: uid)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) return query.docs.first.data();

      return null;
    } catch (e) {
      return null;
    }
  }

  Future<String> getAddressFromCoords(double? lat, double? lng) async {
    if (lat == null || lng == null) return "Không rõ địa chỉ";

    final cacheKey = "$lat,$lng";
    if (_addressCache.containsKey(cacheKey)) return _addressCache[cacheKey]!;

    try {
      String address = "";
      if (kIsWeb) {
        final url = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1',
        );
        final response = await http.get(
          url,
          headers: {
            'Accept-Language': 'vi',
            'User-Agent': 'project_cuoi_ky/1.0',
          },
        );
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          address = data['display_name'] ?? "$lat, $lng";
        }
      } else {
        final placemarks = await placemarkFromCoordinates(lat, lng);
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          final parts = <String>[];
          if ((p.street ?? '').trim().isNotEmpty) parts.add(p.street!.trim());
          if ((p.subAdministrativeArea ?? '').trim().isNotEmpty) {
            parts.add(p.subAdministrativeArea!.trim());
          }
          if ((p.administrativeArea ?? '').trim().isNotEmpty) {
            parts.add(p.administrativeArea!.trim());
          }

          address = parts.join(', ');

          final countryCode = (p.isoCountryCode ?? '').trim().toUpperCase();
          if ((address.isEmpty ||
                  countryCode.isNotEmpty && countryCode != 'VN') &&
              _looksLikeVietnamCoords(lat, lng)) {
            address = (await _reverseWithNominatimVietnam(lat, lng)) ?? address;
          }
        } else if (_looksLikeVietnamCoords(lat, lng)) {
          address = (await _reverseWithNominatimVietnam(lat, lng)) ?? '';
        }
      }

      if (address.isNotEmpty) {
        _addressCache[cacheKey] = address;
        return address;
      }
    } catch (e) {
      return "$lat, $lng";
    }
    return "$lat, $lng";
  }
}
