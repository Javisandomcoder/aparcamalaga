import 'package:flutter/material.dart';

import '../features/parking/presentation/pages/parking_map_page.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aparca Málaga PMR',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF006494)),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F9FC),
      ),
      home: const ParkingMapPage(),
    );
  }
}
