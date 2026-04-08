import 'dart:convert';
import 'package:http/http.dart' as http;

class WeatherService {
  static const String _apiKey = '69e421edced71ebe2aa8ec8069c8394a';
  static const String _baseUrl = 'https://api.openweathermap.org/data/2.5/weather';

  final double lat = 6.8213;
  final double lon = 80.0416;

  Future<Map<String, dynamic>> fetchWeather() async {
    final url = Uri.parse('$_baseUrl?lat=$lat&lon=$lon&appid=$_apiKey&units=metric');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load weather data');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }
}
