import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../account/account_header.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(
        children: [
          const AccountHeader(),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.key),
            title: const Text('AI ključevi'),
            subtitle: const Text('Gemini, Groq, OpenRouter'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/profile/ai-keys'),
          ),
        ],
      ),
    );
  }
}
