import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme.dart';

class WeatherWidget extends StatelessWidget {
  final Map<String, dynamic>? userData;
  final dynamic weatherService;

  const WeatherWidget({
    super.key,
    required this.userData,
    required this.weatherService,
  });

  Map<String, dynamic> _getTimeTheme() {
    final hour = DateTime.now().hour;

    if (hour >= 5 && hour < 12) {
      return {
        "greeting": "Good Morning",
        "colors": [const Color(0xFF794B75).withOpacity(0.9), const Color(0xFFFFE8B2).withOpacity(0.9)],
        "wallpaper": 'assets/images/morning.jpg',
      };
    } else if (hour >= 12 && hour < 16) {
      return {
        "greeting": "Good Afternoon",
        "colors": [const Color(0xFF1474C8).withOpacity(0.9), const Color(0xFF1474C8).withOpacity(0.7)],
        "wallpaper": 'assets/images/afternoon.jpg',
      };
    } else if (hour >= 16 && hour < 19) {
      return {
        "greeting": "Good Evening",
        "colors": [const Color(0xFFFF8000).withOpacity(0.9), const Color(0xFFFFD79F).withOpacity(0.8)],
        "wallpaper": 'assets/images/evening.jpg',
      };
    } else {
      return {
        "greeting": "Good Night",
        "colors": [const Color(0xFF011641).withOpacity(0.95), const Color(0xFF014F9A).withOpacity(0.9)],
        "wallpaper": 'assets/images/night.jpg',
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = _getTimeTheme();
    final String currentImagePath = theme['wallpaper'];

    return FutureBuilder<Map<String, dynamic>>(
      future: weatherService.fetchWeather(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator())
          );
        }
        if (snapshot.hasError || !snapshot.hasData) return const SizedBox.shrink();

        final data = snapshot.data!;
        final temp = data['main']['temp'].round();
        final description = data['weather'][0]['description'];
        final iconCode = data['weather'][0]['icon'];
        final humidity = data['main']['humidity'];

        return Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: theme['colors'],
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: Stack(
              children: [
                Positioned(
                  left: 100,
                  right: -40,
                  top: 0,
                  bottom: 0,
                  child: ShaderMask(
                    shaderCallback: (rect) => LinearGradient(
                      begin: const Alignment(-0.8, -0.2),
                      end: const Alignment(0.2, 0.2),
                      colors: [Colors.transparent, Colors.white],
                      stops: const [0.0, 0.9],
                    ).createShader(rect),
                    blendMode: BlendMode.dstIn,
                    child: Image.asset(currentImagePath, fit: BoxFit.cover),
                  ),
                ),

                Positioned.fill(
                  child: ShaderMask(
                    shaderCallback: (rect) => const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [Colors.white, Colors.transparent],
                      stops: [0.0, 0.7],
                    ).createShader(rect),
                    blendMode: BlendMode.dstIn,
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(color: Colors.white.withOpacity(0.05)),
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            theme['greeting'],
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    blurRadius: 8.0,
                                    color: Colors.black.withOpacity(0.3),
                                    offset: const Offset(1, 1),
                                  ),
                                ],
                                fontStyle: FontStyle.italic),
                          ),
                          Text(
                            "${userData?['first_name'] ?? ''} ${userData?['last_name'] ?? ''}",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  blurRadius: 8.0,
                                  color: Colors.black.withOpacity(0.3),
                                  offset: const Offset(1, 1),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text("$temp°C",
                                  style: TextStyle(
                                      shadows: [
                                        Shadow(
                                          blurRadius: 8.0,
                                          color: Colors.black.withOpacity(0.3),
                                          offset: const Offset(1, 1),
                                        ),
                                      ],
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white)),
                              const SizedBox(width: 4),
                              Image.network(
                                  "https://openweathermap.org/img/wn/$iconCode.png",
                                  width: 40,
                                  height: 40),
                            ],
                          ),
                          Text(description.toString().toUpperCase(),
                              style: TextStyle(
                                  shadows: [
                                    Shadow(
                                      blurRadius: 8.0,
                                      color: Colors.black.withOpacity(0.3),
                                      offset: const Offset(1, 1),
                                    ),
                                  ],
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 1.2)),
                          Text("Humidity: $humidity%",
                              style: TextStyle(
                                  shadows: [
                                    Shadow(
                                      blurRadius: 8.0,
                                      color: Colors.black.withOpacity(0.3),
                                      offset: const Offset(1, 1),
                                    ),
                                  ],
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
