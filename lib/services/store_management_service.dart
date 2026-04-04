import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/store_management_models.dart';

class StoreManagementService {
  StoreManagementService({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
    SupabaseClient? supabaseClient,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _supabase = supabaseClient ?? Supabase.instance.client;

  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;
  final SupabaseClient _supabase;

  static const String _ordersCollection = 'Orders';
  static const String _reviewsCollection = 'Reviews';
  static const String _usersCollection = 'Users';
  static const String _storeImageBucket = String.fromEnvironment(
    'SUPABASE_STORE_STORAGE_BUCKET',
    defaultValue: '',
  );
  static const String _fallbackImageBucket = String.fromEnvironment(
    'SUPABASE_STORAGE_BUCKET',
    defaultValue: 'food-images',
  );

  String get currentStoreId {
    final id = _firebaseAuth.currentUser?.uid.trim() ?? '';
    if (id.isEmpty) {
      throw StateError('Bạn chưa đăng nhập.');
    }
    return id;
  }

  Stream<List<StoreTicket>> watchStoreTickets() {
    final storeId = currentStoreId;

    return _firestore.collection(_ordersCollection).snapshots().map((snapshot) {
      final items = snapshot.docs
          .where((doc) => _matchesStore(doc.data(), storeId))
          .map(
            (doc) =>
                StoreTicket.fromMap(_normalizeDocumentData(doc.id, doc.data())),
          )
          .toList();
      items.sort((left, right) {
        final rightTime = right.createdAt?.millisecondsSinceEpoch ?? 0;
        final leftTime = left.createdAt?.millisecondsSinceEpoch ?? 0;
        return rightTime.compareTo(leftTime);
      });
      return items;
    });
  }

  Stream<StoreStats> watchStats() {
    return watchStoreTickets().asyncMap((tickets) async {
      var totalRevenue = 0.0;

      for (final ticket in tickets) {
        if (ticket.status == StoreTicketStatus.completed) {
          totalRevenue += ticket.totalAmount;
        }
      }

      int todayTickets;
      try {
        todayTickets = await _fetchTodayTicketsByOrderTime();
      } on FirebaseException catch (e) {
        // Fallback when Firestore composite index for order_time query
        // has not been created yet.
        if (e.code == 'failed-precondition') {
          todayTickets = _countTodayTicketsFromLoadedList(tickets);
        } else {
          rethrow;
        }
      }

      return StoreStats(
        totalRevenue: totalRevenue,
        totalTickets: tickets.length,
        todayTickets: todayTickets,
      );
    });
  }

  int _countTodayTicketsFromLoadedList(List<StoreTicket> tickets) {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return tickets.where((ticket) {
      final createdAt = ticket.createdAt;
      if (createdAt == null) {
        return false;
      }
      return !createdAt.isBefore(startOfDay) && createdAt.isBefore(endOfDay);
    }).length;
  }

  Future<int> _fetchTodayTicketsByOrderTime() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final snapshot = await _firestore
        .collection(_ordersCollection)
        .where(
          'order_time',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
        )
        .where('order_time', isLessThan: Timestamp.fromDate(endOfDay))
        .get();

    final storeId = currentStoreId;
    return snapshot.docs
        .where((doc) => _matchesStore(doc.data(), storeId))
        .length;
  }

  Future<void> updateTicketStatus({
    required String ticketId,
    required StoreTicketStatus status,
  }) async {
    await _firestore
        .collection(_ordersCollection)
        .doc(ticketId)
        .set(<String, dynamic>{
          'status': status.value,
          'order_status': status.value,
          'updated_at': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'store_id': currentStoreId,
        }, SetOptions(merge: true));
  }

  Stream<List<StoreReview>> watchReviews() {
    final storeId = currentStoreId;

    return _firestore
        .collection(_reviewsCollection)
        .where('store_id', isEqualTo: storeId)
        .snapshots()
        .map((snapshot) {
          final items = snapshot.docs
              .where((doc) => _matchesStore(doc.data(), storeId))
              .map(
                (doc) => StoreReview.fromMap(
                  _normalizeDocumentData(doc.id, doc.data()),
                ),
              )
              .toList();
          items.sort((left, right) {
            final rightTime = right.createdAt?.millisecondsSinceEpoch ?? 0;
            final leftTime = left.createdAt?.millisecondsSinceEpoch ?? 0;
            return rightTime.compareTo(leftTime);
          });
          return items;
        });
  }

  Future<void> replyReview({
    required String reviewId,
    required String reply,
  }) async {
    final trimmedReply = reply.trim();

    await _firestore
        .collection(_reviewsCollection)
        .doc(reviewId)
        .set(<String, dynamic>{
          'owner_reply': trimmedReply,
          'ownerReply': trimmedReply,
          'store_reply': trimmedReply,
          'reply': trimmedReply,
          'owner_replied_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'store_id': currentStoreId,
        }, SetOptions(merge: true));
  }

  Future<StoreProfile> getStoreProfile() async {
    final storeId = currentStoreId;

    final byId = await _firestore
        .collection(_usersCollection)
        .doc(storeId)
        .get();
    if (byId.exists) {
      return StoreProfile.fromMap(
        _normalizeDocumentData(byId.id, byId.data() ?? <String, dynamic>{}),
      );
    }

    return StoreProfile.empty;
  }

  Stream<StoreProfile> watchStoreProfile() {
    final storeId = currentStoreId;

    return _firestore.collection(_usersCollection).doc(storeId).snapshots().map(
      (snapshot) {
        if (!snapshot.exists) {
          return StoreProfile.empty;
        }

        return StoreProfile.fromMap(
          _normalizeDocumentData(
            snapshot.id,
            snapshot.data() ?? <String, dynamic>{},
          ),
        );
      },
    );
  }

  Future<void> updateStoreProfile(
    StoreProfile profile, {
    double? latitude,
    double? longitude,
  }) async {
    final storeId = currentStoreId;

    final currentDoc = await _firestore
        .collection(_usersCollection)
        .doc(storeId)
        .get();
    final currentData = currentDoc.data() ?? <String, dynamic>{};

    final normalizedStoreInfo = _extractStoreInfoMap(currentData);
    final currentImageUrl = _asText(
      currentData['image_url'] ??
          currentData['imageUrl'] ??
          normalizedStoreInfo['image_url'] ??
          normalizedStoreInfo['imageUrl'],
    );
    final nextImageUrl = profile.imageUrl.trim().isNotEmpty
        ? profile.imageUrl.trim()
        : currentImageUrl;
    final resolvedLocation = (latitude != null && longitude != null)
        ? _ResolvedLocation(latitude, longitude)
        : await _resolveLocation(
            address: profile.address,
            currentData: currentData,
            storeInfo: normalizedStoreInfo,
          );

    final storeInfoEntry = <String, dynamic>{
      ...normalizedStoreInfo,
      'store_name': profile.storeName.trim(),
      'phone': profile.phone.trim(),
      'address': profile.address.trim(),
      'opening_hours': profile.openingHours.trim(),
      if (nextImageUrl.isNotEmpty) 'image_url': nextImageUrl,
      'latitude': resolvedLocation.latitude,
      'longitude': resolvedLocation.longitude,
      'position': _formatPosition(
        resolvedLocation.latitude,
        resolvedLocation.longitude,
      ),
      'is_open': normalizedStoreInfo['is_open'] is bool
          ? normalizedStoreInfo['is_open']
          : true,
      'rating': normalizedStoreInfo['rating'] is num
          ? normalizedStoreInfo['rating']
          : 0.0,
    };

    final payload = <String, dynamic>{
      'fullName': profile.storeName.trim(),
      ...profile.toMap(),
      if (nextImageUrl.isNotEmpty) 'image_url': nextImageUrl,
      'latitude': resolvedLocation.latitude,
      'longitude': resolvedLocation.longitude,
      'position': _formatPosition(
        resolvedLocation.latitude,
        resolvedLocation.longitude,
      ),
      'store_info': <Map<String, dynamic>>[storeInfoEntry],
      'updated_at': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await _firestore
        .collection(_usersCollection)
        .doc(storeId)
        .set(payload, SetOptions(merge: true));
  }

  Future<void> updateStoreImageUrl(String imageUrl) async {
    final storeId = currentStoreId;
    final trimmed = imageUrl.trim();
    if (trimmed.isEmpty) {
      return;
    }

    await _firestore.collection(_usersCollection).doc(storeId).set({
      'image_url': trimmed,
      'imageUrl': trimmed,
      'updated_at': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Map<String, dynamic> _extractStoreInfoMap(Map<String, dynamic> raw) {
    final info = raw['store_info'];
    if (info is List && info.isNotEmpty && info.first is Map<String, dynamic>) {
      return Map<String, dynamic>.from(info.first as Map<String, dynamic>);
    }
    if (info is Map<String, dynamic>) {
      final item = info['0'];
      if (item is Map<String, dynamic>) {
        return Map<String, dynamic>.from(item);
      }
    }
    return <String, dynamic>{};
  }

  Future<_ResolvedLocation> _resolveLocation({
    required String address,
    required Map<String, dynamic> currentData,
    required Map<String, dynamic> storeInfo,
  }) async {
    final trimmedAddress = address.trim();
    if (trimmedAddress.isNotEmpty) {
      try {
        final locations = await locationFromAddress(trimmedAddress);
        if (locations.isNotEmpty) {
          final first = locations.first;
          return _ResolvedLocation(first.latitude, first.longitude);
        }
      } catch (_) {
        // Fallback to existing saved coordinates if geocoding fails.
      }
    }

    final lat = _asDouble(
      currentData['latitude'] ?? storeInfo['latitude'] ?? 0,
    );
    final lng = _asDouble(
      currentData['longitude'] ?? storeInfo['longitude'] ?? 0,
    );
    return _ResolvedLocation(lat, lng);
  }

  double _asDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.trim()) ?? 0;
    }
    return 0;
  }

  String _asText(dynamic value) {
    if (value == null) {
      return '';
    }
    return value.toString().trim();
  }

  String _formatPosition(double latitude, double longitude) {
    final latDirection = latitude >= 0 ? 'N' : 'S';
    final lngDirection = longitude >= 0 ? 'E' : 'W';
    final latAbs = latitude.abs().toStringAsFixed(6);
    final lngAbs = longitude.abs().toStringAsFixed(6);
    return '[$latAbs $latDirection, $lngAbs $lngDirection]';
  }

  Future<String> uploadStoreImage({
    required Uint8List bytes,
    required String fileExtension,
    String? bucket,
  }) async {
    final storeId = currentStoreId;

    final sanitizedExt = fileExtension.toLowerCase().replaceAll('.', '').trim();
    final ext = sanitizedExt.isEmpty ? 'jpg' : sanitizedExt;
    final path =
        'stores/$storeId/profile_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final preferredBucket = (bucket ?? _storeImageBucket).trim().isNotEmpty
        ? (bucket ?? _storeImageBucket).trim()
        : _fallbackImageBucket;

    try {
      await _supabase.storage
          .from(preferredBucket)
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(upsert: false),
          );
      return _supabase.storage.from(preferredBucket).getPublicUrl(path);
    } on StorageException catch (error) {
      final shouldRetryWithFallback =
          preferredBucket != _fallbackImageBucket && error.statusCode == '404';
      if (!shouldRetryWithFallback) {
        if (error.statusCode == '403') {
          throw StateError(
            'Supabase Storage dang chan upload (403 Unauthorized). '
            'Can them policy INSERT cho bucket "$preferredBucket" (hoac "$_fallbackImageBucket") '
            'va folder stores/.',
          );
        }
        rethrow;
      }

      try {
        await _supabase.storage
            .from(_fallbackImageBucket)
            .uploadBinary(
              path,
              bytes,
              fileOptions: const FileOptions(upsert: false),
            );
        return _supabase.storage.from(_fallbackImageBucket).getPublicUrl(path);
      } on StorageException catch (fallbackError) {
        if (fallbackError.statusCode == '403') {
          throw StateError(
            'Supabase Storage dang chan upload (403 Unauthorized). '
            'Can them policy INSERT cho bucket "$_fallbackImageBucket" va folder stores/.',
          );
        }
        rethrow;
      }
    }
  }

  Map<String, dynamic> _normalizeDocumentData(
    String documentId,
    Map<String, dynamic> raw,
  ) {
    final normalized = <String, dynamic>{'id': documentId};
    raw.forEach((key, value) {
      if (value is Timestamp) {
        normalized[key] = value.toDate();
      } else {
        normalized[key] = value;
      }
    });
    return normalized;
  }

  bool _matchesStore(Map<String, dynamic> raw, String storeId) {
    final candidates = <dynamic>[
      raw['store_id'],
      raw['storeId'],
      raw['owner_id'],
      raw['ownerId'],
      raw['uid'],
      raw['user_id'],
      raw['userId'],
    ];

    for (final candidate in candidates) {
      if (candidate?.toString().trim() == storeId) {
        return true;
      }
    }
    return false;
  }
}

class _ResolvedLocation {
  const _ResolvedLocation(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}
