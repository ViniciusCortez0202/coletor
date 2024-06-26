import 'package:coletor/pages/colect_page.dart';
import 'package:coletor/start_scan_page.dart';
import 'package:coletor/position_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

void main() {
  FlutterBluePlus.setLogLevel(LogLevel.verbose, color: true);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(      
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
        
      routes: {
        '/': (context) => const ColectPage(),
        '/colect': (context) => const StartScandPage(),
        '/position': (context) => const PositionPage()
      },
    );
  }
}
