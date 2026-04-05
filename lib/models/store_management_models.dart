class StoreTicketStatus {
  const StoreTicketStatus(this.value, this.label);

  static const pending = StoreTicketStatus('pending', 'Chờ xác nhận');
  static const preparing = StoreTicketStatus('preparing', 'Đang chuẩn bị');
  static const findingDriver = StoreTicketStatus(
    'finding_driver',
    'Đang tìm tài xế',
  );
  static const delivering = StoreTicketStatus('delivering', 'Đang giao');
  static const completed = StoreTicketStatus('completed', 'Hoàn thành');
  static const cancelled = StoreTicketStatus('cancelled', 'Đã hủy');

  static const values = <StoreTicketStatus>[
    pending,
    preparing,
    findingDriver,
    delivering,
    completed,
    cancelled,
  ];

  final String value;
  final String label;

  static StoreTicketStatus fromAny(dynamic value) {
    final normalized = value?.toString().trim().toLowerCase() ?? '';
    if (normalized == 'delivered') {
      return completed;
    }
    if (normalized == 'on_the_way') {
      return delivering;
    }
    if (normalized == 'searching' || normalized == 'dang_tim_xe') {
      return findingDriver;
    }
    for (final status in values) {
      if (status.value == normalized) {
        return status;
      }
    }
    return pending;
  }
}

class StoreTicket {
  const StoreTicket({
    required this.id,
    required this.customerName,
    required this.totalAmount,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String customerName;
  final double totalAmount;
  final StoreTicketStatus status;
  final DateTime? createdAt;

  factory StoreTicket.fromMap(Map<String, dynamic> map) {
    return StoreTicket(
      id: asText(map['id']),
      customerName: asText(map['customer_name']).isNotEmpty
          ? asText(map['customer_name'])
          : (asText(map['customerName']).isNotEmpty
                ? asText(map['customerName'])
                : 'Khách hàng'),
      totalAmount: asDouble(
        map['total_amount'] ??
            map['totalAmount'] ??
            map['total'] ??
            map['amount'] ??
            map['price'],
      ),
      status: StoreTicketStatus.fromAny(map['status'] ?? map['order_status']),
      createdAt: asDateTime(
        map['order_time'] ??
            map['orderTime'] ??
            map['created_at'] ??
            map['createdAt'],
      ),
    );
  }
}

class StoreStats {
  const StoreStats({
    required this.totalRevenue,
    required this.totalTickets,
    required this.todayTickets,
  });

  final double totalRevenue;
  final int totalTickets;
  final int todayTickets;

  static const empty = StoreStats(
    totalRevenue: 0,
    totalTickets: 0,
    todayTickets: 0,
  );
}

class StoreReview {
  const StoreReview({
    required this.id,
    required this.customerName,
    required this.rating,
    required this.content,
    required this.ownerReply,
    required this.createdAt,
  });

  final String id;
  final String customerName;
  final int rating;
  final String content;
  final String ownerReply;
  final DateTime? createdAt;

  bool get hasReply => ownerReply.trim().isNotEmpty;

  factory StoreReview.fromMap(Map<String, dynamic> map) {
    return StoreReview(
      id: asText(map['id']),
      customerName: asText(map['customer_name']).isNotEmpty
          ? asText(map['customer_name'])
          : (asText(map['customerName']).isNotEmpty
                ? asText(map['customerName'])
                : 'Khách hàng'),
      rating: asInt(map['rating'] ?? map['stars'] ?? map['star']),
      content: asText(map['content']).isNotEmpty
          ? asText(map['content'])
          : (asText(map['comment']).isNotEmpty
                ? asText(map['comment'])
                : asText(map['review'])),
      ownerReply: asText(map['owner_reply']).isNotEmpty
          ? asText(map['owner_reply'])
          : (asText(map['store_reply']).isNotEmpty
                ? asText(map['store_reply'])
                : (asText(map['ownerReply']).isNotEmpty
                      ? asText(map['ownerReply'])
                      : asText(map['reply']))),
      createdAt: asDateTime(
        map['created_at'] ??
            map['createdAt'] ??
            map['time'] ??
            map['timestamp'],
      ),
    );
  }
}

class StoreProfile {
  const StoreProfile({
    required this.storeName,
    required this.phone,
    required this.address,
    required this.openingHours,
    required this.imageUrl,
    this.latitude,
    this.longitude,
  });

  final String storeName;
  final String phone;
  final String address;
  final String openingHours;
  final String imageUrl;
  final double? latitude;
  final double? longitude;

  factory StoreProfile.fromMap(Map<String, dynamic> map) {
    final storeInfo = _extractStoreInfo(map['store_info']);

    final inferredStoreName = asText(storeInfo['store_name']).isNotEmpty
        ? asText(storeInfo['store_name'])
        : (asText(storeInfo['name']).isNotEmpty
              ? asText(storeInfo['name'])
              : asText(storeInfo['fullName']));

    final inferredOpeningHours = asText(storeInfo['opening_hours']).isNotEmpty
        ? asText(storeInfo['opening_hours'])
        : asText(storeInfo['hours']);

    final inferredImageUrl = asText(storeInfo['image_url']).isNotEmpty
        ? asText(storeInfo['image_url'])
        : asText(storeInfo['imageUrl']);

    return StoreProfile(
      storeName: asText(map['store_name']).isNotEmpty
          ? asText(map['store_name'])
          : (asText(map['name']).isNotEmpty
                ? asText(map['name'])
                : (asText(map['full_name']).isNotEmpty
                      ? asText(map['full_name'])
                      : (asText(map['fullName']).isNotEmpty
                            ? asText(map['fullName'])
                            : inferredStoreName))),
      phone: asText(map['phone']).isNotEmpty
          ? asText(map['phone'])
          : asText(storeInfo['phone']),
      address: asText(map['address']).isNotEmpty
          ? asText(map['address'])
          : asText(storeInfo['address']),
      openingHours: asText(map['opening_hours']).isNotEmpty
          ? asText(map['opening_hours'])
          : (asText(map['hours']).isNotEmpty
                ? asText(map['hours'])
                : inferredOpeningHours),
      imageUrl: asText(map['image_url']).isNotEmpty
          ? asText(map['image_url'])
          : (asText(map['imageUrl']).isNotEmpty
                ? asText(map['imageUrl'])
                : inferredImageUrl),
      latitude: asNullableDouble(map['latitude'] ?? storeInfo['latitude']),
      longitude: asNullableDouble(map['longitude'] ?? storeInfo['longitude']),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'store_name': storeName.trim(),
      'phone': phone.trim(),
      'address': address.trim(),
      'opening_hours': openingHours.trim(),
      'image_url': imageUrl.trim(),
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    };
  }

  static const empty = StoreProfile(
    storeName: '',
    phone: '',
    address: '',
    openingHours: '',
    imageUrl: '',
    latitude: null,
    longitude: null,
  );
}

Map<String, dynamic> _extractStoreInfo(dynamic value) {
  if (value is Map<String, dynamic>) {
    final firstNumericKey =
        value.keys.where((key) => int.tryParse(key) != null).toList()
          ..sort((left, right) => int.parse(left).compareTo(int.parse(right)));

    if (firstNumericKey.isNotEmpty) {
      final firstItem = value[firstNumericKey.first];
      if (firstItem is Map<String, dynamic>) {
        return firstItem;
      }
    }
    return value;
  }

  if (value is List && value.isNotEmpty) {
    final firstItem = value.first;
    if (firstItem is Map<String, dynamic>) {
      return firstItem;
    }
  }

  return const <String, dynamic>{};
}

String asText(dynamic value) => value?.toString().trim() ?? '';

double asDouble(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value.trim()) ?? 0;
  }
  return 0;
}

double? asNullableDouble(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    final parsed = double.tryParse(value.trim());
    return parsed;
  }
  return null;
}

int asInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value.trim()) ?? 0;
  }
  return 0;
}

DateTime? asDateTime(dynamic value) {
  if (value is DateTime) {
    return value;
  }
  if (value is String && value.trim().isNotEmpty) {
    return DateTime.tryParse(value.trim());
  }
  return null;
}
