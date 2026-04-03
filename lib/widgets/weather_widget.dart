import 'package:flutter/material.dart';
import '../services/recommendation_service.dart';
import '../theme/app_colors.dart';

class WeatherWidget extends StatelessWidget {
  final WeatherData? weather;
  final VoidCallback? onRefresh;

  const WeatherWidget({
    super.key,
    this.weather,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    // Nếu chưa có thời tiết, hiển thị placeholder mờ hoặc loading
    final bool isWeatherLoaded = weather != null;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isWeatherLoaded 
              ? _getWeatherColors(weather!.condition)
              : [Colors.grey[400]!, Colors.grey[600]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isWeatherLoaded ? _getGreeting(weather!.condition) : 'Đang tải thời tiết...',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isWeatherLoaded 
                      ? '${weather!.temp.toStringAsFixed(1)}°C • ${weather!.description}'
                      : 'Vui lòng đợi trong giây lát',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isWeatherLoaded 
                      ? _getRecommendationText(weather!.condition, weather!.temp)
                      : 'Đang tìm kiếm gợi ý phù hợp...',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            children: [
              if (isWeatherLoaded)
                Image.network(
                  weather!.iconUrl,
                  width: 64,
                  height: 64,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.wb_sunny, color: Colors.white, size: 48),
                )
              else
                const SizedBox(
                  width: 64,
                  height: 64,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Colors.white70,
                      strokeWidth: 3,
                    ),
                  ),
                ),
              if (onRefresh != null)
                IconButton(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh, color: Colors.white70, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
        ],
      ),
    );
  }

  List<Color> _getWeatherColors(String condition) {
    switch (condition) {
      case 'Rain':
      case 'Drizzle':
      case 'Thunderstorm':
        return [const Color(0xFF4B6CB7), const Color(0xFF182848)];
      case 'Clear':
        return [const Color(0xFF2193b0), const Color(0xFF6dd5ed)];
      case 'Clouds':
        return [const Color(0xFFbdc3c7), const Color(0xFF2c3e50)];
      default:
        return [AppColors.primary, AppColors.primary.withOpacity(0.7)];
    }
  }

  String _getGreeting(String condition) {
    switch (condition) {
      case 'Rain':
        return 'Trời đang mưa rồi!';
      case 'Clear':
        return 'Nắng đẹp quá!';
      case 'Clouds':
        return 'Trời nhiều mây';
      default:
        return 'Chào ngày mới!';
    }
  }

  String _getRecommendationText(String condition, double temp) {
    if (condition == 'Rain') return 'Làm bát súp nóng cho ấm người nhé?';
    if (temp > 28) return 'Nắng nóng thế này, làm cốc trà sữa đá thôi!';
    if (temp < 20) return 'Se lạnh rồi, ăn món gì nóng hổi đi!';
    return 'Thời tiết thật đẹp để thưởng thức món ngon!';
  }
}
