import 'package:flutter/material.dart';

import 'home_page.dart';

void main() {
  runApp(const IdTaggerApp());
}

class IdTaggerApp extends StatelessWidget {
  const IdTaggerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ID3 Tagger',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple)),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
      ),
      home: const HomePage(),
    );
  }
}
