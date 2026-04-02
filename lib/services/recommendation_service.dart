import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/store_info.dart';
import '../models/food_item.dart';
import '../models/app_user.dart';

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

  // Lấy dữ liệu thời tiết từ OpenWeatherMap hoặc API khác
  Future<String?> getWeatherCondition(double latitude, double longitude) async {
    try {
      // Sử dụng OpenWeatherMap API (cần đăng ký)
      const apiKey = 'b704cff89bc96af48c452f7a03cc433d'; // Thay API key của bạn
      final url =
          'https://api.openweathermap.org/data/weather?lat=$latitude&lon=$longitude&appid=$apiKey&units=metric';

      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 5),
        onTimeout: () => http.Response('timeout', 408),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['weather'][0]['main']; // Ví dụ: "Rainy", "Sunny"
      }
      return null;
    } catch (e) {
      return null; // Nếu lỗi, vẫn tiếp tục
    }
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

  // Gợi ý combo thực đơn dựa trên thời tiết
  Future<List<FoodItem>> getWeatherBasedFoodRecommendations(
    List<FoodItem> foods,
    double userLat,
    double userLon,
  ) async {
    try {
      final weather = await getWeatherCondition(userLat, userLon);

      // Từ khóa gợi ý theo thời tiết
      final weatherKeywords = {
        'Rainy': ['cơm', 'súp', 'nóng', 'nước nóng'],
        'Sunny': ['nước', 'kem', 'salad', 'sinh tố', 'lạnh'],
        'Cloudy': ['mì', 'bánh', 'cà phê'],
        'Cold': ['nóng', 'cơm', 'thịt', 'súp'],
        'Hot': ['đá', 'lạnh', 'kem', 'nước'],
      };

      final keywords = weatherKeywords[weather] ?? [];

      final recommended = foods.where((food) {
        final name = (food.name ?? '').toLowerCase();
        final description = (food.description ?? '').toLowerCase();
        return keywords.any((keyword) =>
            name.contains(keyword) || description.contains(keyword));
      }).toList();

      // Sắp xếp theo rating
      recommended.sort((a, b) {
        final aRating = a.avgRating ?? 0;
        final bRating = b.avgRating ?? 0;
        return bRating.compareTo(aRating);
      });

      return recommended.take(10).toList();
    } catch (e) {
      return foods..sort((a, b) => (b.avgRating ?? 0).compareTo(a.avgRating ?? 0));
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
