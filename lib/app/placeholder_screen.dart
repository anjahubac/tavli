import 'package:flutter/material.dart';

import '../features/account/account_header.dart';

class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return EmptyStateScreen(
      appBarTitle: title,
      art: Icon(icon, size: 56, color: colors.primary),
      title: 'Uskoro',
    );
  }
}

/// Tab bez sadržaja: animacija (ili ikona), naslov i objašnjenje.
class EmptyStateScreen extends StatelessWidget {
  const EmptyStateScreen({
    super.key,
    required this.appBarTitle,
    required this.art,
    required this.title,
    this.body,
  });

  final String appBarTitle;
  final Widget art;
  final String title;
  final String? body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle),
        actions: const [ProfileButton()],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                art,
                const SizedBox(height: 20),
                Text(
                  title,
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                if (body case final body?) ...[
                  const SizedBox(height: 8),
                  Text(
                    body,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
