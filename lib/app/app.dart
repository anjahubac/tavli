import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'router.dart';

/// Topla boja tave/terakote.
const _seed = Color(0xFFD2643C);

class TavliApp extends StatelessWidget {
  const TavliApp({super.key, this.router});

  /// Za testove; inače [appRouter].
  final GoRouter? router;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Tavli',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: _seed),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seed,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      routerConfig: router ?? appRouter,
    );
  }
}
