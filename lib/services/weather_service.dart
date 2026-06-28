import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Weather alert model for hyperlocal delivery warnings
class WeatherAlert {
  final String condition; // e.g. 'Rain', 'Thunderstorm', 'Clear'
  final String description;
  final double tempCelsius;
  final int humidity;
  final double windSpeed;
  final String iconCode;
  final bool hasWarning;
  final String warningMessage;

  WeatherAlert({
    required this.condition,
    required this.description,
    required this.tempCelsius,
    required this.humidity,
    required this.windSpeed,
    required this.iconCode,
    this.hasWarning = false,
    this.warningMessage = '',
  });
}

class WeatherService {
  // Free-tier OpenWeatherMap API key (set via env or config)
  static const String _apiKey = String.fromEnvironment(
    'OPENWEATHER_API_KEY',
    defaultValue: '',
  );
  static const String _baseUrl =
      'https://api.openweathermap.org/data/2.5/weather';

  /// Fetches current weather for a given lat/lng.
  /// Falls back to a safe default if the API key is missing or the call fails.
  static Future<WeatherAlert> getCurrentWeather({
    double latitude = 26.9124,
    double longitude = 75.7873,
  }) async {
    // If no API key, return a simulated mild weather
    if (_apiKey.isEmpty) {
      return _getSimulatedWeather();
    }

    try {
      final url = Uri.parse(
        '$_baseUrl?lat=$latitude&lon=$longitude&appid=$_apiKey&units=metric',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return _parseWeather(data as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('WeatherService error: $e');
    }

    return _getSimulatedWeather();
  }

  static WeatherAlert _parseWeather(Map<String, dynamic> data) {
    final weather = data['weather'][0];
    final main = data['main'];
    final wind = data['wind'];

    final condition = weather['main'] as String;
    final description = weather['description'] as String;
    final temp = (main['temp'] as num).toDouble();
    final humidity = (main['humidity'] as num).toInt();
    final windSpeed = (wind['speed'] as num).toDouble();
    final icon = weather['icon'] as String;

    // Determine if a warning should be shown
    bool hasWarning = false;
    String warningMessage = '';

    if (['Thunderstorm', 'Tornado', 'Squall'].contains(condition)) {
      hasWarning = true;
      warningMessage =
          '⚠️ Severe weather alert! Deliveries may be delayed by 30-60 minutes due to $description.';
    } else if (condition == 'Rain' || condition == 'Drizzle') {
      hasWarning = true;
      warningMessage =
          '🌧️ Rain expected in your area. Deliveries may take 15-30 extra minutes.';
    } else if (temp >= 45) {
      hasWarning = true;
      warningMessage =
          '🔥 Extreme heat (${temp.round()}°C)! Perishable items will use insulated packaging.';
    } else if (windSpeed > 15) {
      hasWarning = true;
      warningMessage =
          '💨 High winds detected. Rider safety measures may add 10-20 min delay.';
    }

    return WeatherAlert(
      condition: condition,
      description: description,
      tempCelsius: temp,
      humidity: humidity,
      windSpeed: windSpeed,
      iconCode: icon,
      hasWarning: hasWarning,
      warningMessage: warningMessage,
    );
  }

  /// Provides a realistic simulated weather for demo/offline mode.
  /// Cycles through conditions based on the current hour.
  static WeatherAlert _getSimulatedWeather() {
    final hour = DateTime.now().hour;

    // Simulate different conditions based on time of day
    if (hour >= 14 && hour <= 17) {
      // Afternoon — simulate light rain during monsoon season
      return WeatherAlert(
        condition: 'Rain',
        description: 'light rain',
        tempCelsius: 32,
        humidity: 78,
        windSpeed: 8.5,
        iconCode: '10d',
        hasWarning: true,
        warningMessage:
            '🌧️ Light rain expected in your area. Deliveries may take 15-30 extra minutes.',
      );
    } else if (hour >= 18 || hour < 6) {
      // Night — clear skies
      return WeatherAlert(
        condition: 'Clear',
        description: 'clear sky',
        tempCelsius: 28,
        humidity: 55,
        windSpeed: 3.2,
        iconCode: '01n',
      );
    } else {
      // Morning/midday — sunny
      return WeatherAlert(
        condition: 'Clear',
        description: 'sunny',
        tempCelsius: 36,
        humidity: 42,
        windSpeed: 4.1,
        iconCode: '01d',
      );
    }
  }

  /// Gets the weather icon URL from OpenWeather
  static String getIconUrl(String iconCode) {
    return 'https://openweathermap.org/img/wn/$iconCode@2x.png';
  }
}
