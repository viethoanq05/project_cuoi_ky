import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
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
      // Sử dụng OpenWeatherMap API (cần đăng ký)
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
    double userLon,
  ) async {
    try {
      if (foods.isEmpty || stores.isEmpty) return foods;

      // 1. Tạo bản đồ ID cửa hàng -> Khoảng cách
      final Map<String, double> storeDistances = {};
      for (var store in stores) {
        final dist = _calculateDistance(userLat, userLon, store.latitude, store.longitude);
        storeDistances[store.storeId] = dist;
      }

      // 2. Gán khoảng cách cho mỗi món ăn (nếu món đó có storeId) và lọc
      final List<MapEntry<FoodItem, double>> foodWithDistance = [];
      for (var food in foods) {
        if (storeDistances.containsKey(food.storeId)) {
          foodWithDistance.add(MapEntry(food, storeDistances[food.storeId]!));
        }
      }

      // 3. Sắp xếp theo khoảng cách tăng dần (gần nhất lên đầu)
      foodWithDistance.sort((a, b) => a.value.compareTo(b.value));

      // 4. Trả về danh sách món ăn đã sắp xếp
      return foodWithDistance.map((e) => e.key).take(20).toList();
    } catch (e) {
      debugPrint('Error getting distance-based recommendations: $e');
      return foods.take(10).toList();
    }
  }

  // Deprecated: dùng getWeatherData thay thế
  Future<String?> getWeatherCondition(double latitude, double longitude) async {
    final data = await getWeatherData(latitude, longitude);
    return data?.condition;
  }

  // Gợi ý cửa hàng dựa trên thời tiết
  Future<List<StoreInfo>> getWeatherBasedRecommendations(
    List<StoreInfo> stores,
    double userLat,
    double userLon,
  ) async {
    try {
      final weather = await getWeatherCondition(userLat, userLon);

      // Gợi ý dựa trên thời tiết
      Map<String, List<String>> weatherCategories = {
        'Rainy': ['Cơm', 'Nước nóng', 'Cháo', 'Súp'],
        'Sunny': ['Nước uống', 'Kem', 'Salad', 'Trái cây'],
        'Cloudy': ['Cơm', 'Mì', 'Bánh mì', 'Cà phê'],
        'Cold': ['Cơm nóng', 'Súp', 'Nước nóng', 'Thịt nướng'],
        'Hot': ['Nước đá', 'Sinh tố', 'Kem', 'Salad'],
      };

      final suggestions = weatherCategories[weather] ?? [];

      // Sắp xếp cửa hàng dựa trên gợi ý thời tiết
      final scored = stores.map((store) {
        final distanceMetric =
            _calculateDistance(userLat, userLon, store.latitude, store.longitude);
        final score = store.rating != null ? store.rating! * 2 : 0;
        final distance = 5 / (distanceMetric + 1); // Cân bằng khoảng cách

        return store.copyWith(
          distance: distanceMetric,
          weatherCondition: weather,
        );
      }).toList();

      // Sắp xếp theo đánh giá và khoảng cách
      scored.sort((a, b) {
        final aScore =
            (a.rating ?? 0) - (a.distance ?? 10) / 2; // Ưu tiên rating cao, gần
        final bScore = (b.rating ?? 0) - (b.distance ?? 10) / 2;
        return bScore.compareTo(aScore);
      });

      return scored;
    } catch (e) {
      return stores..sort((a, b) => (a.distance ?? 999).compareTo(b.distance ?? 999));
    }
  }

  // Gợi ý món ăn dựa trên dữ liệu thời tiết thực tế
  Future<List<FoodItem>> getWeatherBasedFoodRecommendations(
    List<FoodItem> foods,
    WeatherData? weather,
  ) async {
    try {
      if (weather == null) return foods.take(10).toList();

      final condition = weather.condition;
      final temp = weather.temp;

      // Từ khóa gợi ý theo thời tiết và nhiệt độ
      final List<String> keywords = [];

      if (condition == 'Rain' || condition == 'Drizzle' || condition == 'Thunderstorm') {
        keywords.addAll(['cơm', 'súp', 'nóng', 'cháo', 'phở', 'bún']);
      } else if (condition == 'Clear' || condition == 'Clouds') {
        if (temp > 28) {
          keywords.addAll(['đá', 'lạnh', 'nước', 'kem', 'sinh tố', 'salad', 'trà sữa']);
        } else if (temp < 20) {
          keywords.addAll(['nóng', 'cơm', 'nướng', 'lẩu']);
        } else {
          keywords.addAll(['bánh', 'mì', 'cà phê', 'trà', 'ăn vặt']);
        }
      }

      final recommended = foods.where((food) {
        final name = (food.name).toLowerCase();
        final description = (food.description).toLowerCase();
        return keywords.any((keyword) =>
            name.contains(keyword) || description.contains(keyword));
      }).toList();

      // Sắp xếp theo rating
      recommended.sort((a, b) {
        final bRating = b.avgRating;
        final aRating = a.avgRating;
        return bRating.compareTo(aRating);
      });

      return recommended.take(15).toList();
    } catch (e) {
      return foods.take(10).toList();
    }
  }

  // Gợi ý dựa trên lịch sử đơn hàng (collaborative filtering đơn giản)
  Future<List<FoodItem>> getPersonalizedRecommendations(
    List<FoodItem> availableFoods,
    List<String> previousFoodIds,
  ) async {
    try {
      // Lọc những món chưa gọi
      final untriedFoods = availableFoods
          .where((food) => !previousFoodIds.contains(food.foodId))
          .toList();

      // Nếu có, sắp xếp theo rating
      untriedFoods.sort((a, b) {
        final aRating = a.avgRating ?? 0;
        final bRating = b.avgRating ?? 0;
        return bRating.compareTo(aRating);
      });

      return untriedFoods.take(10).toList();
    } catch (e) {
      return availableFoods;
    }
  }
}
