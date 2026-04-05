import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'dart:convert';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Cache địa chỉ để tránh gọi API nhiều lần
  static final Map<String, String> _addressCache = {};

  Future<Map<String, dynamic>?> getUserById(String uid) async {
    if (uid.isEmpty) return null;
    try {
      final doc = await _firestore.collection('Users').doc(uid).get();
      if (doc.exists) return doc.data();
      
      final query = await _firestore.collection('Users').where('email', isEqualTo: uid).limit(1).get();
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
        final url = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1');
        final response = await http.get(url, headers: {'Accept-Language': 'vi'});
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          address = data['display_name'] ?? "$lat, $lng";
        }
      } else {
        List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
        if (placemarks.isNotEmpty) {
          Placemark p = placemarks.first;
          List<String> parts = [];
          if (p.street != null && p.street!.isNotEmpty) parts.add(p.street!);
          if (p.subAdministrativeArea != null && p.subAdministrativeArea!.isNotEmpty) parts.add(p.subAdministrativeArea!);
          if (p.administrativeArea != null && p.administrativeArea!.isNotEmpty) parts.add(p.administrativeArea!);
          address = parts.join(', ');
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
