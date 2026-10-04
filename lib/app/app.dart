import 'package:flutter/material.dart';

import '../features/home/presentation/home_screen.dart';
import 'theme.dart';

class RaicesApp extends StatelessWidget {
  const RaicesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Raíces',
      debugShowCheckedModeBanner: false,
      theme: buildRaicesTheme(),
      home: const HomeScreen(),
    );
  }
}
