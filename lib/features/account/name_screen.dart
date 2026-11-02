import 'package:flutter/material.dart';

/// Obavezan korak sa imenom (dovršava se u US2).
class NameScreen extends StatelessWidget {
  const NameScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Kako da te zovemo?')));
}
