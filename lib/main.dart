import 'package:flutter/material.dart';
import 'view/detection_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Object Detection',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const DetectionPage(),
    );
  }
}