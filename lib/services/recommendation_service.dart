import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/store_info.dart';
import '../models/food_item.dart';
import '../models/app_user.dart';

class WeatherData {
  final String condition;
  final double temp;
  final String description;
  final String iconCode;

  WeatherData({
    required this.condition,
    required this.temp,
    required this.description,
    required this.iconCode,
  });

  String get iconUrl => 'https://openweathermap.org/img/wn/$iconCode@2x.png';
}

class RecommendationService {
  static final RecommendationService _instance = RecommendationService._internal();

  factory RecommendationService() {
    return _instance;
  }

  RecommendationService._internal();

  // Tính khoảng cách giữa 2 điểm GPS (Haversine formula)
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371; // Bán kính Trái Đất (km)
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _toRad(double degree) {
    return degree * pi / 180;
  }

  // Lấy cửa hàng gần nhất dựa trên vị trí hiện tại
  Future<List<StoreInfo>> getNearbyStores(
    AppUser currentUser, {
    double radiusKm = 5.0,
    List<StoreInfo>? allStores,
  }) async {
    try {
      if (currentUser.position == null) {
        return [];
      }

      final userLat = currentUser.position!['latitude']!;
      final userLon = currentUser.position!['longitude']!;

      if (allStores == null || allStores.isEmpty) {
        return [];
      }

      final nearby = allStores.where((store) {
        final distance = _calculateDistance(
          userLat,
          userLon,
          store.latitude,
          store.longitude,
        );
        return distance <= radiusKm;
      }).map((store) {
        final distance = _calculateDistance(
          userLat,
          userLon,
          store.latitude,
          store.longitude,
        );
        return store.copyWith(distance: distance);
      }).toList();

      // Sắp xếp theo khoảng cách
      nearby.sort((a, b) => (a.distance ?? 999).compareTo(b.distance ?? 999));

      return nearby;
    } catch (e) {
      rethrow;
    }
  }

  // Lấy dữ liệu thời tiết chi tiết từ OpenWeatherMap
  Future<WeatherData?> getWeatherData(double latitude, double longitude) async {
    try {
      // Sử dụng OpenWeatherMap API
      const apiKey = 'b704cff89bc96af48c452f7a03cc433d';
      final url =
          'https://api.openweathermap.org/data/2.5/weather?lat=$latitude&lon=$longitude&appid=$apiKey&units=metric&lang=vi';

      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 5),
        onTimeout: () => http.Response('timeout', 408),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return WeatherData(
          condition: data['weather'][0]['main'],
          temp: (data['main']['temp'] as num).toDouble(),
          description: data['weather'][0]['description'],
          iconCode: data['weather'][0]['icon'],
        );
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching weather: $e');
      return null;
    }
  }

  // Gợi ý món ăn dựa trên khoảng cách của cửa hàng
  Future<List<FoodItem>> getDistanceBasedFoodRecommendations(
    List<FoodItem> foods,
    List<StoreInfo> stores,
    double userLat,
    double userLon, {
    int limit = 20,
  }) async {
    try {
      if (foods.isEmpty || stores.isEmpty) return foods;

      final Map<String, double> storeDistances = {};
      for (var store in stores) {
        final dist = _calculateDistance(userLat, userLon, store.latitude, store.longitude);
        storeDistances[store.storeId] = dist;
      }

      final List<MapEntry<FoodItem, double>> foodWithDistance = [];
      for (var food in foods) {
        if (storeDistances.containsKey(food.storeId)) {
          foodWithDistance.add(MapEntry(food, storeDistances[food.storeId]!));
        }
      }

      foodWithDistance.sort((a, b) => a.value.compareTo(b.value));
      
      if (limit > 0) {
        return foodWithDistance.map((e) => e.key).take(limit).toList();
      } else {
        return foodWithDistance.map((e) => e.key).toList();
      }
    } catch (e) {
      debugPrint('Error getting distance-based recommendations: $e');
      return foods.take(limit > 0 ? limit : 10).toList();
    }
  }

  // Gợi ý cửa hàng dựa trên thời tiết
  Future<List<StoreInfo>> getWeatherBasedRecommendations(
    List<StoreInfo> stores,
    double userLat,
    double userLon,
  ) async {
    try {
      final weatherData = await getWeatherData(userLat, userLon);
      final weather = weatherData?.condition;

      final scored = stores.map((store) {
        final distanceMetric =
            _calculateDistance(userLat, userLon, store.latitude, store.longitude);
        return store.copyWith(
          distance: distanceMetric,
          weatherCondition: weather,
        );
      }).toList();

      scored.sort((a, b) {
        final aScore = (a.rating ?? 0) - (a.distance ?? 10) / 2;
        final bScore = (b.rating ?? 0) - (b.distance ?? 10) / 2;
        return bScore.compareTo(aScore);
      });

      return scored;
    } catch (e) {
      return stores..sort((a, b) => (a.distance ?? 999).compareTo(b.distance ?? 999));
    }
  }

  // Gợi ý món ăn dựa trên thời tiết thực tế và thời gian trong ngày
  Future<List<FoodItem>> getWeatherBasedFoodRecommendations(
    List<FoodItem> foods,
    WeatherData? weather, {
    DateTime? currentTime,
  }) async {
    try {
      final now = currentTime ?? DateTime.now();
      final hour = now.hour;
      final List<String> keywords = [];

      // 1. Thêm từ khóa theo buổi
      keywords.addAll(_getTimeBasedKeywords(hour));

      // 2. Thêm từ khóa theo thời tiết
      if (weather != null) {
        final condition = weather.condition;
        final temp = weather.temp;

        if (condition == 'Rain' || condition == 'Drizzle' || condition == 'Thunderstorm' || condition == 'Squall' || condition == 'Tornado') {
          keywords.addAll(['hot', 'soup', 'chao', 'pho', 'bun', 'lau', 'cay', 'nong']);
        } else if (condition == 'Clear' || condition == 'Clouds' || condition == 'Mist' || condition == 'Haze' || condition == 'Fog') {
          if (temp > 28) {
            keywords.addAll(['da', 'lanh', 'nuoc', 'kem', 'sinh to', 'salad', 'tra sua', 'che']);
          } else if (temp < 22) {
            keywords.addAll(['nong', 'nuong', 'lau', 'cay', 'sot', 'ramen']);
          }
        }
      }

      // Chuẩn hóa và lọc món ăn
      final normalizedKeywords = keywords.map((k) => _removeDiacritics(k.toLowerCase())).toSet().toList();
      
      final recommended = foods.where((food) {
        final name = _removeDiacritics(food.name.toLowerCase());
        final desc = _removeDiacritics(food.description.toLowerCase());
        return normalizedKeywords.any((k) => name.contains(k) || desc.contains(k));
      }).toList();

      // Fallback: nếu không khớp, lấy top món đánh giá cao
      if (recommended.isEmpty && foods.isNotEmpty) {
        final fallback = List<FoodItem>.from(foods);
        fallback.sort((a, b) => b.avgRating.compareTo(a.avgRating));
        return fallback.take(10).toList();
      }

      recommended.sort((a, b) => b.avgRating.compareTo(a.avgRating));
      return recommended.take(15).toList();
    } catch (e) {
      return foods.take(10).toList();
    }
  }

  // Gợi ý dựa trên lịch sử đơn hàng
  Future<List<FoodItem>> getPersonalizedRecommendations(
    List<FoodItem> availableFoods,
    List<String> previousFoodIds,
  ) async {
    try {
      final untriedFoods = availableFoods
          .where((food) => !previousFoodIds.contains(food.foodId))
          .toList();

      untriedFoods.sort((a, b) => b.avgRating.compareTo(a.avgRating));
      return untriedFoods.take(10).toList();
    } catch (e) {
      return availableFoods;
    }
  }

  List<String> _getTimeBasedKeywords(int hour) {
    if (hour >= 5 && hour < 10) {
      return ['sang', 'bun', 'pho', 'xoi', 'banh mi', 'ca phe'];
    } else if (hour >= 10 && hour < 14) {
      return ['trua', 'com', 'van phong', 'bun dau', 'pho'];
    } else if (hour >= 17 && hour < 22) {
      return ['toi', 'lau', 'nuong', 'com', 'gia dinh'];
    } else if (hour >= 22 || hour < 5) {
      return ['dem', 'an vat', 'oc', 'hu tieu', 'tra sua'];
    }
    return ['ngon'];
  }

  String _removeDiacritics(String str) {
    var withDiacritics = 'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴÈÉẸẺẼÊỀẾỆỂỄÌÍỊỈĨÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠÙÚỤỦŨƯỪỨỰỬỮỲÝỴỶỸĐ';
    var withoutDiacritics = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyydAAAAAAAAAAAAAAAAAEEEEEEEEEEEIIIIIOOOOOOOOOOOOOOOOOUUUUUUUUUUUYYYYYD';
    
    for (int i = 0; i < withDiacritics.length; i++) {
        str = str.replaceAll(withDiacritics[i], withoutDiacritics[i]);
    }
    return str;
  }
}
