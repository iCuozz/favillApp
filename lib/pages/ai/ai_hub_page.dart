import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../services/settings_service.dart';
import 'ask_favilla_page.dart';
import 'mission_generator_page.dart';
import 'my_missions_page.dart';

/// Hub centrale delle feature AI: punto unico di accesso dalla home.
class AiHubPage extends StatelessWidget {
  const AiHubPage({super.key});

  void _open(BuildContext context, Widget page) {
    SettingsService.tapFeedback();
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.aiHubTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              AppStrings.aiHubIntro,
              style: TextStyle(color: Colors.grey.shade300, height: 1.4),
            ),
            const SizedBox(height: 16),
            _AiCard(
              icon: Icons.chat_bubble_outline,
              title: AppStrings.askFavillaTitle,
              subtitle: AppStrings.askFavillaSubtitle,
              accent: Colors.pinkAccent,
              onTap: () => _open(context, const AskFavillaPage()),
            ),
            _AiCard(
              icon: Icons.auto_fix_high,
              title: AppStrings.missionTitle,
              subtitle: AppStrings.missionSubtitle,
              accent: Colors.deepPurpleAccent,
              onTap: () => _open(context, const MissionGeneratorPage()),
            ),
            _AiCard(
              icon: Icons.collections_bookmark_outlined,
              title: AppStrings.missionMyCollection,
              subtitle: AppStrings.missionMyCollectionSubtitle,
              accent: Colors.teal,
              onTap: () => _open(context, const MyMissionsPage()),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  const _AiCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: accent.withAlpha(60),
          child: Icon(icon, color: accent),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
